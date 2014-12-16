--db:fhirb
--{{{
-- row with query param and all required meta information
drop type if exists query_param cascade;
create type query_param AS (
  parent_resource text, -- if chained params parent resource
  link_path text[], -- path of reference attribute, used in join
  resource_type text, -- name of resource
  chain text[], -- chain array
  search_type text,
  is_primitive boolean,
  type text,
  field_path text[], -- search attribute path in resource
  key text,
  operator text,
  value text[] -- values array with OR semantic
);

-- extract type from search key subject:Patient => Patient
-- if no type take first from possible types
-- TODO: should return all possible types!
CREATE OR REPLACE
FUNCTION get_reference_type(_key text,  _types text[]) RETURNS text
language sql AS $$
    SELECT
        CASE WHEN position(':' in _key ) > 0 THEN
           split_part(_key, ':', 2)
        WHEN array_length(_types, 1) = 1 THEN
          _types[1]
        ELSE
          null -- TODO: think about this case
        END
$$ IMMUTABLE;

-- this recursive function collect metainformation for
-- chained params

--DROP FUNCTION IF EXISTS _expand_search_params(_resource_type text, _query text);
CREATE OR REPLACE
FUNCTION _expand_search_params(_resource_type text, _query text)
RETURNS setof query_param
LANGUAGE sql AS $$
  WITH RECURSIVE params(parent_resource, link_path, res, chain, key, operator, value) AS (
    -- this is inital select
    -- it produce some rows where key length > 1
    -- and we expand them joining meta inforamtion
    SELECT null::text as parent_resource, -- we start with empty parent resoure
           '{}'::text[] as link_path, -- path of reference attribute to join
           _resource_type::text as res, -- this is resource to apply condition
           ARRAY[_resource_type]::text[] || key as chain,
           key as key,
           operator as operator,
           value as value
    FROM _parse_param(_query)
    WHERE key[1] NOT IN ('_tag', '_security', '_profile', '_sort', '_count', '_page')

    UNION

    SELECT res as parent_resource, -- move res to parent_resource
           _rest(ri.path) as link_path,
           get_reference_type(x.key[1], re.ref_type) as res, -- set next res in chain
           x.chain AS chain, -- save search path
           _rest(x.key) AS key, -- remove first item from key untill only one key left
           x.operator,
           x.value
     FROM  params x
     JOIN  fhir.resource_indexables ri
       ON  ri.param_name = split_part(key[1], ':',1)
      AND  ri.resource_type = x.res
     JOIN  fhir.resource_elements re
       ON  re.path = ri.path
    WHERE array_length(key,1) > 1
  )
  SELECT
    parent_resource as parent_resource,
    link_path as link_path,
    res as resource_type,
    _butlast(p.chain) as chain,
    ri.search_type,
    ri.is_primitive,
    ri.type,
    _rest(ri.path)::text[] as field_path,
    key[1] as key,
    operator,
    value
  FROM params p
  JOIN fhir.resource_indexables ri
    ON ri.resource_type = res
   AND ri.param_name = key[1]
 where array_length(key,1) = 1
  ORDER by p.chain
  ;
$$;

-- this function build condition to search by identifier
CREATE OR REPLACE
FUNCTION build_identifier_cond(tbl text, _q query_param)
RETURNS text
LANGUAGE sql AS $$
SELECT format('%I.logical_id IN (%s)', tbl, string_agg((E'\'' || x || E'\'::uuid'),','))
FROM unnest(_q.value) x
$$;

-- this function build condition to search string using ilike
-- expected trigram index on expression
-- (index_as_string(content, '{name}') ilike '%term%' OR index_as_string(content,'{name}') ilike '%term2')
CREATE OR REPLACE
FUNCTION build_string_cond(tbl text, _q query_param)
RETURNS text
LANGUAGE sql AS $$
SELECT '(' || string_agg(
    format('index_as_string(%I.content, %L) ilike %L', tbl, _q.field_path, '%' || x || '%'),
    ' OR ') || ')'
FROM unnest(_q.value) x
$$;

-- build condition for token
-- (index_codeableconcept_as_token(content, '{name}') &&  '{term,term2}'varachr[])
CREATE OR REPLACE
FUNCTION build_token_cond(tbl text, _q query_param)
RETURNS text
LANGUAGE sql AS $$
SELECT
  format('%s(%I.content, %L) && %L::varchar[]',
    _token_index_fn(_q.type, _q.is_primitive),
    tbl,
    _q.field_path,
    _q.value)
$$;

CREATE OR REPLACE
FUNCTION build_date_cond(tbl text, _q query_param)
RETURNS text
LANGUAGE sql AS $$
SELECT
'(' ||
string_agg(
  format('index_as_date(content, %L, %L) && %L',
    _q.field_path,
    _q.type,
    (
      case
      when _q.operator = '=' then
        _datetime_to_tstzrange(v, v)
      when _q.operator = '>' then
        _datetime_to_tstzrange(v, NULL)
      when _q.operator = '<' then
        ('(,' || _date_parse_to_upper(v) || ']' )::tstzrange
      end
    )
  )
,' OR ')
|| ')'
FROM unnest(_q.value) v
$$ IMMUTABLE;

-- build condition for reference
-- (index_as_reference(content, '{name}') &&  '{term,term2}'varachr[])
-- TODO: respect modifier provider:Organization=id => 'Organization/id'
CREATE OR REPLACE
FUNCTION build_reference_cond(tbl text, _q query_param)
RETURNS text
LANGUAGE sql AS $$
SELECT
  format('index_as_reference(content, %L) && %L::varchar[]', _q.field_path, _q.value)
$$ IMMUTABLE;


CREATE OR REPLACE
FUNCTION build_cond(tbl text, _q query_param)
RETURNS text
LANGUAGE sql AS $$
  SELECT
  CASE
  WHEN _q.search_type = 'identifier' THEN
    build_identifier_cond(tbl, _q)
  WHEN _q.search_type = 'string' THEN
    build_string_cond(tbl, _q)
  WHEN _q.search_type = 'token' THEN
    build_token_cond(tbl, _q)
  WHEN _q.search_type = 'date' THEN
    build_date_cond(tbl, _q)
  WHEN _q.search_type = 'reference' THEN
    build_reference_cond(tbl, _q)
  END as cnd
$$;

CREATE OR REPLACE
FUNCTION build_sorting(_resource_type varchar, _query text)
RETURNS text
LANGUAGE sql AS $$

WITH params AS (
  SELECT ROW_NUMBER() OVER () as weight,
         value[1] as param_name,
         case when operator='desc'
          then 'DESC'
          else 'ASC'
          end as direction
    FROM _parse_param(_query) q
   WHERE key[1] = '_sort'
), with_meta AS (
  SELECT *
    FROM params x
    JOIN fhir.resource_indexables fr
      ON fr.resource_type = _resource_type
     AND fr.param_name = x.param_name
ORDER BY weight
)
SELECT k.column1
|| string_agg(
  format(E'(json_get_in(%I.content, \'%s\'))[1]::text %s', lower(_resource_type), _rest(y.path)::text, y.direction)
  ,E', ')
FROM with_meta y, (VALUES(E'\n ORDER BY ')) k -- we join for manadic effect, if no sorting parmas return null
GROUP BY k.column1
$$;

-- TODO add to documentation
-- custom sort param _sort:asc=a, _sort:desc=b => { _sort:["a:asc", "b:desc"] }
CREATE OR REPLACE
FUNCTION build_search_query(_resource_type text, _query text) RETURNS text
LANGUAGE sql AS $$
WITH conds AS (
  SELECT
    build_cond(lower(resource_type),row(x.*))::text as cond,
    resource_type,
    chain,
    link_path,
    parent_resource
  FROM  _expand_search_params(_resource_type, _query) x
), joins AS ( --TODO: what if no middle join present ie we have a.b.c.attr = x and no a.b.attr condition
  SELECT
    format(E'JOIN %I ON index_as_reference(%I.content, %L) && ARRAY[%I.logical_id]::varchar[] AND \n %s',
      lower(resource_type),
      lower(parent_resource),
      link_path,
      lower(resource_type),
      string_agg(cond, E'\nAND')) sql
    FROM conds
    WHERE parent_resource IS NOT NULL
    GROUP BY resource_type, parent_resource, chain, link_path
    ORDER by chain
), special_params AS (
  SELECT key[1] as key, value[1] as value
  FROM _parse_param(_query)
  where key[1] ilike '_%'
)

SELECT
format('SELECT %I.* FROM %I ', lower(_resource_type), lower(_resource_type))
|| E'\n' || COALESCE((SELECT string_agg(sql, E'\n')::text FROM joins), ' ')
|| E'\nWHERE '
|| COALESCE((SELECT string_agg(cond, ' AND ')
    FROM conds
    WHERE parent_resource IS NULL
    GROUP BY resource_type), ' true = true ')
|| COALESCE(build_sorting(_resource_type, _query), '')
|| format(E'\nLIMIT %s',COALESCE( (SELECT value::integer FROM special_params WHERE key = '_count'), '100'))
$$;


DROP FUNCTION IF EXISTS search(_resource_type text, query text);
CREATE FUNCTION
search(_resource_type text, query text)
RETURNS SETOF resource
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY EXECUTE build_search_query(_resource_type, query);
END
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS explain_search(_resource_type text, query text);
CREATE FUNCTION
explain_search(_resource_type text, query text)
RETURNS table( "plan" text)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY EXECUTE 'EXPLAIN ANALYZE ' || build_search_query(_resource_type, query);
END
$$;

CREATE OR REPLACE
FUNCTION fhir_search(_cfg jsonb, _type_ text, _params_ text) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM search(_type_, _params_) r
  )
  SELECT _build_bundle(
    'Search ' || _type_  || ' by ' || _params_,
    (SELECT count(*)::int FROM entry),
    (SELECT COALESCE(json_agg(entry),'[]'::json) FROM entry e)
  );
$$;
--}}}
