--db:fhirb
--{{{
-- TODO: all by convetion
CREATE OR REPLACE FUNCTION
_param_expression(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
WITH val_cond AS (SELECT
  CASE WHEN _type = 'string' THEN
    _search_string_expression(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'token' THEN
    _search_token_expression(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'date' THEN
    _search_date_expression(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'quantity' THEN
    _search_quantity_expression(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'reference' THEN
    _search_reference_expression(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'number' THEN
    _search_number_expression(_table, _param, _type, _modifier, regexp_split_to_table)
  ELSE 'implement_me' END as cond
  FROM regexp_split_to_table(_value, ','))
SELECT
  _tpl('({{tbl}}.param = {{param}} AND ({{vals_cond}}))'
       , 'tbl', quote_ident(_table)
       , 'param', quote_literal(_param)
       , 'vals_cond',
       (SELECT string_agg(cond, ' OR ') FROM val_cond));
$$;


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

CREATE OR REPLACE
FUNCTION get_alias_from_path( _path text[]) RETURNS text
language sql AS $$
    SELECT
      regexp_replace(
       lower(array_to_string(_path, '_')),
       E'\\W', '') ;
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _param_expression_tag(_table varchar, _key varchar, _val varchar, _modifier varchar) RETURNS text
LANGUAGE sql AS $$
 SELECT
  '(' ||
  CASE
  WHEN _key = '_security' THEN
    _table || '.scheme = ''http://hl7.org/fhir/tag/security'' AND '
  WHEN _key = '_profile' THEN
    _table || '.scheme = ''http://hl7.org/fhir/tag/profile'' AND '
  ElSE
    ''
  END ||

  CASE
  WHEN _modifier = 'text' THEN
    _table || '.label ILIKE ' || quote_literal('%' || _val || '%')
  WHEN _modifier = 'partial' THEN
    _table || '.term  ILIKE ' || quote_literal(_val || '%')
  ELSE
    _table || '.term = ' || quote_literal(_val)
  END
  || ')';
$$;

CREATE OR REPLACE
FUNCTION expand_params(_resource_type text, _query jsonb)
RETURNS table (parent_res text, res text, path text[], key text, value text)
LANGUAGE sql AS $$
  WITH RECURSIVE params(parent_res, res, path, key, value) AS (
    SELECT null::text as parent_res,
           _resource_type::text as res,
           ARRAY[_resource_type]::text[] as path,
           x.key,
           x.value
      FROM jsonb_each_text(_query) x
     WHERE split_part(x.key,':',1) NOT IN ('_tag', '_security', '_profile', '_sort')

    UNION

    SELECT res as parent_res,
           get_reference_type(split_part(x.key, '.', 1), re.ref_type) as res,
           array_append(x.path,split_part(key, '.', 1)) as path,
           (regexp_matches(key, '^([^.]+)\.(.+)'))[2] AS key,
           value
     FROM  params x
     JOIN  fhir.resource_indexables ri
       ON  ri.param_name = split_part(split_part(x.key, '.', 1), ':',1)
      AND  ri.resource_type = x.res
     JOIN  fhir.resource_elements re
       ON  re.path = ri.path
  )
  SELECT * from params;
$$;


CREATE OR REPLACE
FUNCTION _build_index_joins(_resource_type text, _query jsonb)
RETURNS table (sql text, weight text)
LANGUAGE sql AS $$
    SELECT _tpl($SQL$
            JOIN {{tbl}} {{als}}
              ON {{als}}.resource_id::varchar = {{prnt}}.logical_id::varchar
             AND {{cond}}
          $SQL$,
          'tbl',  quote_ident(lower(p.res) || '_search_' || fri.search_type),
          'als',  get_alias_from_path(array_append(p.path, fri.search_type::text)),
          'prnt', get_alias_from_path(p.path),
          'cond', string_agg(
                     _param_expression( get_alias_from_path(array_append(p.path, fri.search_type::text)),
                                       fri.param_name,
                                       fri.search_type,
                                       split_part(p.key, ':', 2),
                                       p.value), ' AND ')) as join_str
           ,p.path::text || '2' as weight
       FROM expand_params(_resource_type, _query) p
       JOIN fhir.resource_indexables fri
         ON fri.param_name = split_part(p.key, ':', 1)
        AND fri.resource_type =  p.res
      WHERE position('.' in p.key) = 0
      GROUP BY p.res, p.path, fri.search_type
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _build_references_joins(_resource_type text, _query jsonb)
RETURNS table (sql text, weight text)
LANGUAGE sql AS $$
    -- joins trhough referenced resources for chained params
    SELECT _tpl($SQL$
            JOIN {{tbl}} {{als}}
              ON {{als}}.resource_id::varchar = {{prnt}}.logical_id::varchar
           $SQL$,
           'tbl', quote_ident(lower(p.parent_res) || '_references'),
           'als', get_alias_from_path(p.path),
           'prnt', get_alias_from_path(_butlast(p.path)))
           AS join_str
            ,p.path::text || '1'  as weight
      FROM expand_params(_resource_type, _query) p
      WHERE parent_res is not null
      GROUP BY p.parent_res, res, path
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _build_tags_joins(_resource_type text, _query jsonb)
RETURNS table (sql text, weight text)
LANGUAGE sql AS $$
    SELECT _tpl($SQL$
            JOIN {{tbl}} {{als}}
              ON {{als}}.resource_id = {{prnt}}.logical_id
             AND {{cond}}
           $SQL$,
           'tbl', lower(_resource_type || '_tag'),
           'als',  y.als,
           'cond', string_agg(_param_expression_tag(y.als, y.key, y.value, y.modifier), ' OR '),
           'prnt', quote_ident(lower(_resource_type)))
            as sql,
            '0'::text as weight
      FROM (
        SELECT quote_ident('_' || md5(x.value::text)) as als,
               split_part(x.key,':',1) as key,
               split_part(x.key,':',2) as modifier,
               regexp_split_to_table as value
          FROM jsonb_each_text(_query) x,
               regexp_split_to_table(x.value, ',')
         WHERE split_part(x.key,':',1) IN ('_tag', '_security', '_profile')
      ) y
      GROUP BY y.als, y.key, y.modifier
$$ IMMUTABLE;


CREATE OR REPLACE
FUNCTION build_search_joins(_resource_type text, _query jsonb) RETURNS text
LANGUAGE sql AS $$
  -- recursivelly expand chained params
  WITH joins AS  (
    SELECT * FROM _build_tags_joins(_resource_type, _query)
    UNION ALL
    SELECT * FROM _build_index_joins(_resource_type, _query)
    UNION ALL
    SELECT * FROM _build_references_joins(_resource_type, _query)
  )
  -- agg to SQL string
  SELECT string_agg(sql, '')
    FROM (SELECT sql  FROM joins ORDER BY weight LIMIT 1000) _ ;
$$;

CREATE OR REPLACE FUNCTION
parse_order_params(_resource_type varchar, query jsonb)
RETURNS TABLE(param text, direction text) LANGUAGE sql AS $$
  SELECT split_part(jsonb_array_elements_text, ':', 1) AS param,
         CASE WHEN split_part(jsonb_array_elements_text, ':', 2) = '' THEN
           'ASC'
         ELSE
           CASE WHEN upper(split_part(jsonb_array_elements_text, ':', 2)) = 'ASC' THEN
             'ASC'
           ELSE
             'DESC'
           END
         END AS direction
    FROM jsonb_array_elements_text(query->'_sort')
   WHERE position('.' IN jsonb_array_elements_text) = 0
$$;

CREATE OR REPLACE FUNCTION
build_order_clause(_resource_type varchar, query jsonb)
RETURNS text LANGUAGE sql AS $$
  WITH order_strs AS (
    SELECT _tpl($SQL$
             {{param_tbl}}.{{param_clmn}} {{dir}}
           $SQL$,
           'param_tbl', lower(_resource_type) || '_' || param || '_order_idx',
           'param_clmn', CASE WHEN direction = 'ASC' THEN 'lower' ELSE 'upper' END,
           'dir', CASE WHEN direction = 'ASC' THEN 'ASC' ELSE 'DESC' END) AS str
      FROM parse_order_params(_resource_type, query)
  )
  SELECT CASE WHEN length(string_agg(str, '')) > 0 THEN
           'ORDER BY ' || string_agg(str, ', ')
         ELSE
           'ORDER BY logical_id ASC'
         END
    FROM order_strs
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
build_order_joins(_resource_type varchar, query jsonb)
RETURNS text LANGUAGE sql AS $$
  WITH joins AS (
    SELECT _tpl($SQL$
      LEFT JOIN {{order_idx_tbl}} {{order_idx_alias}}
             ON {{order_idx_alias}}.resource_id =
                {{resource_tbl}}.logical_id
                AND {{order_idx_alias}}.param = {{param}}
           $SQL$,
           'order_idx_tbl', lower(_resource_type) || '_sort',
           'order_idx_alias', lower(_resource_type) || '_' || param || '_order_idx',
           'resource_tbl', lower(_resource_type),
           'param', quote_literal(param)) AS j
      FROM parse_order_params(_resource_type, query)
  )
  SELECT string_agg(j, ' ')
    FROM joins;
$$ IMMUTABLE;


CREATE OR REPLACE
FUNCTION _ids_expression(_tbl_ text, ids text) RETURNS text -- sql
LANGUAGE sql AS $$
SELECT CASE
    WHEN ids IS NULL THEN NULL
    ELSE
      (
        SELECT 'WHERE ( ' || string_agg(y.exp,' OR ') || ')' FROM (
          SELECT _tbl_ || '.logical_id=' || quote_literal(x) AS exp
           FROM regexp_split_to_table(ids, ',') x
        ) y
      )
    END
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION build_search_query(_resource_type varchar, query jsonb) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
  _tbl text;
  _count integer;
  _offset integer;
  _page integer;
  _ids_exp text;
  res text;
BEGIN
  _count := COALESCE(query->>'_count', '50')::integer;
  _page := COALESCE(query->>'_page', '0')::integer;
  _offset := _page * _count;
  _tbl := quote_ident(lower(_resource_type));
  _ids_exp := _ids_expression(_tbl, query->>'_id');

  SELECT INTO res
    _tpl($SQL$
      SELECT {{tbl}}.*
        FROM {{tbl}} {{tbl}}
        {{joins}}
        {{ids_search}}
        {{order_clause}}
        LIMIT {{limit}}
        OFFSET {{offset}}
    $SQL$,
    'tbl', _tbl,
    'joins', COALESCE(build_search_joins(_resource_type, query), '') || ' ' ||
             COALESCE(build_order_joins(_resource_type, query), ''),
    'order_clause', build_order_clause(_resource_type, query),
    'ids_search', _ids_exp,
    'limit', _count::varchar,
    'offset', _offset::varchar);

  RETURN res;
END
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
search_results_count(_resource_type varchar, query jsonb)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
  res bigint;
BEGIN
  EXECUTE (
    _tpl($SQL$
      SELECT COUNT({{tbl}}.*)
        FROM {{tbl}} {{tbl}}
        {{joins}}
    $SQL$,
    'tbl', quote_ident(lower(_resource_type)),
    'joins', COALESCE(build_search_joins(_resource_type, query), '')))
  INTO res;

  RETURN res;
END
$$;


DROP FUNCTION IF EXISTS search(character varying,jsonb);
CREATE OR REPLACE FUNCTION
search(_resource_type varchar, query jsonb)
RETURNS TABLE (resource_type varchar, logical_id uuid, version_id uuid, content jsonb, category jsonb, updated timestamptz, published timestamptz, weight bigint, is_included boolean)
LANGUAGE plpgsql AS $$
BEGIN
RETURN QUERY EXECUTE (
  _tpl($SQL$
    WITH
    found_resources AS (
      SELECT x.resource_type,
             x.logical_id,
             x.version_id,
             x.content,
             x.category,
             x.updated,
             x.published,
             ROW_NUMBER() OVER () as weight,
             FALSE as is_included
        FROM ({{search_sql}}) AS x
    ),

    refs_to_include AS (
      SELECT reference_type AS type,
             logical_id AS id
        FROM "{{tbl}}_references" refs
       WHERE resource_id IN (SELECT logical_id FROM found_resources)
         AND path IN (SELECT * FROM jsonb_array_elements_text({{json_includes}}::jsonb))
    ),

    included_resources AS (
      SELECT incres.resource_type,
             incres.logical_id,
             incres.version_id,
             incres.content,
             incres.category,
             incres.updated,
             incres.published,
             0 as weight,
             TRUE as is_included
        FROM resource incres, refs_to_include
       WHERE incres.logical_id::varchar = refs_to_include.id
         AND incres.resource_type = refs_to_include.type
    )

    SELECT * from found_resources
    UNION
    SELECT * from included_resources
    ORDER BY is_included DESC, weight
  $SQL$,
  'json_includes', quote_literal(COALESCE(query->'_include', '[]')),
  'tbl',           LOWER(_resource_type),
  'search_sql',    build_search_query(_resource_type, query)));
END
$$ IMMUTABLE;
--}}}
