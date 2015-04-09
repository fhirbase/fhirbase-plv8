-- #import ./fhirbase_coll.sql
-- #import ./fhirbase_gen.sql
-- #import ./fhirbase_json.sql
-- #import ./fhirbase_crud.sql
-- #import ./fhirbase_date_idx.sql
-- #import ./fhirbase_idx_fns.sql
-- #import ./fhirbase_indexing.sql
-- #import ./fhirbase_params.sql

-- TODO: split into pure functions and search impl

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

func get_reference_type(_key text,  _types text[]) RETURNS text
  -- extract type from search key subject:Patient => Patient
  -- if no type take first from possible types
  -- TODO: should return all possible types!
  SELECT
      CASE WHEN position(':' in _key ) > 0 THEN
         split_part(_key, ':', 2)
      WHEN array_length(_types, 1) = 1 THEN
        _types[1]
      ELSE
        null -- TODO: think about this case
      END

func _expand_search_params(_resource_type text, _query text) RETURNS setof query_param
  -- this recursive function collect metainformation for
  -- chained params
  WITH RECURSIVE params(parent_resource, link_path, res, chain, key, operator, value) AS (
    -- this is inital select
    -- it produce some rows where key length > 1
    -- and we expand them joining meta inforamtion
    SELECT null::text as parent_resource, -- we start with empty parent resoure
           '{}'::text[] as link_path, -- path of reference attribute to join
           _resource_type::text as res, -- this is resource to apply condition
           ARRAY[_resource_type]::text[] || key as chain, -- initial chain
           key as key,
           operator as operator,
           value as value
    FROM fhirbase_params._parse_param(_query)
    WHERE key[1] NOT IN ('_tag', '_security', '_profile', '_sort', '_count', '_page')

    UNION

    SELECT res as parent_resource, -- move res to parent_resource
           fhirbase_coll._rest(ri.path) as link_path, -- remove first element
           this.get_reference_type(x.key[1], re.ref_type) as res, -- set next res in chain
           x.chain AS chain, -- save search path
           fhirbase_coll._rest(x.key) AS key, -- remove first item from key untill only one key left
           x.operator,
           x.value
     FROM  params x
     JOIN  searchparameter ri
       ON  ri.name = split_part(key[1], ':',1)
      AND  ri.base = x.res
     JOIN  structuredefinition_elements re
       ON  re.path = ri.path
    WHERE array_length(key,1) > 1
  )
  SELECT
    parent_resource as parent_resource,
    link_path as link_path,
    res as resource_type,
    fhirbase_coll._butlast(p.chain) as chain,
    ri.search_type,
    ri.is_primitive,
    ri.type,
    fhirbase_coll._rest(ri.path)::text[] as field_path,
    fhirbase_coll._last(key) as key,
    operator,
    value
  FROM params p
  JOIN searchparameter ri
    ON ri.base = res
   AND ri.name = key[1]
 where array_length(key,1) = 1
  ORDER by p.chain

func build_identifier_cond(tbl text, _q query_param) RETURNS text
  -- this function build condition to search by identifier
  SELECT format('%I.logical_id IN (%s)', tbl, string_agg((E'\'' || x || E'\''),','))
  FROM unnest(_q.value) x

func build_string_cond_ilike(tbl text, _q query_param) RETURNS text
  -- this function build condition to search string using ilike
  -- expected trigram index on expression
  -- (index_as_string(content, '{name}') ilike '%term%' OR index_as_string(content,'{name}') ilike '%term2')
  SELECT '(' || string_agg(
      format('fhirbase_idx_fns.index_as_string(%I.content, %L) ilike %L', tbl, _q.field_path, '%' || x || '%'),
      ' OR ') || ')'
  FROM unnest(_q.value) x

func build_string_cond_exact(tbl text, _q query_param) RETURNS text
  -- this function build condition to search string using equals
  -- expected trigram index on expression
  -- (index_as_string(content, '{name}') ilike 'term')
  SELECT '(' || string_agg(
  format('fhirbase_idx_fns.index_as_string(%I.content, %L) ilike %L', tbl, _q.field_path, x),
  ' OR ') || ')'
  FROM unnest(_q.value) x

func build_string_cond(tbl text, _q query_param) RETURNS text
  SELECT
  CASE
  WHEN _q.operator = 'exact' THEN
    this.build_string_cond_exact(tbl, _q)
  ELSE
    this.build_string_cond_ilike(tbl, _q)
  END as cnd

func build_token_cond(tbl text, _q query_param) RETURNS text
  -- build condition for token
  -- (index_codeableconcept_as_token(content, '{name}') &&  '{term,term2}'varachr[])
  SELECT
    format('%s(%I.content, %L) && %L::text[]',
      fhirbase_indexing._token_index_fn(_q.type, _q.is_primitive),
      tbl,
      _q.field_path,
      _q.value)

-- TODO: create tests
func build_date_cond(tbl text, _q query_param) RETURNS text
  SELECT
  '(' ||
  string_agg(
    format('%s (fhirbase_date_idx.index_as_date(content, %L::text[], %L::text) && %L)',
      (
        case
        when _q.operator = '!=' then
          'not '
        else
          ''
        end
      ),
      _q.field_path,
      _q.type,
      (
        case
        when _q.operator = '=' then
          fhirbase_date_idx._datetime_to_tstzrange(v, v)
        when _q.operator = '>' then
          fhirbase_date_idx._datetime_to_tstzrange(v, NULL)
        when _q.operator = '<' then
          ('(,' || fhirbase_date_idx._date_parse_to_upper(v) || ']' )::tstzrange
        when _q.operator = '<=' then
          ('[,' || fhirbase_date_idx._date_parse_to_upper(v) || ']' )::tstzrange
        when _q.operator = '>=' then
          ('[' || fhirbase_date_idx._date_parse_to_lower(v) || ',)' )::tstzrange
        end
      )
    )
  ,' OR ')
  || ')'
  FROM unnest(_q.value) v

func build_reference_cond(tbl text, _q query_param) RETURNS text
  -- build condition for reference
  -- (index_as_reference(content, '{name}') &&  '{term,term2}'varachr[])
  -- TODO: respect modifier provider:Organization=id => 'Organization/id'
 SELECT format('fhirbase_idx_fns.index_as_reference(content, %L) && %L::text[]', _q.field_path, _q.value)

proc! _raise(_msg_ text) RETURNS text
  BEGIN
    EXECUTE
      format('RAISE EXCEPTION %L', _msg_);

func build_cond(tbl text, _q query_param) RETURNS text
  SELECT
  CASE
  WHEN _q.search_type = 'identifier' THEN
    this.build_identifier_cond(tbl, _q)
  WHEN _q.search_type = 'string' THEN
    this.build_string_cond(tbl, _q)
  WHEN _q.search_type = 'token' THEN
    this.build_token_cond(tbl, _q)
  WHEN _q.search_type = 'date' THEN
    this.build_date_cond(tbl, _q)
  WHEN _q.search_type = 'reference' THEN
    this.build_reference_cond(tbl, _q)
  ELSE
    this._raise('Search by type ' || _q.search_type || ' is not yet implemented')
  END as cnd

func build_sorting(_resource_type text, _query text) RETURNS text
  WITH params AS (
    SELECT ROW_NUMBER() OVER () as weight,
           value[1] as param_name,
           case when operator='desc'
            then 'DESC'
            else 'ASC'
            end as direction
      FROM fhirbase_params._parse_param(_query) q
     WHERE key[1] = '_sort'
  ), with_meta AS (
    SELECT *
      FROM params x
      JOIN searchparameter sp
        ON sp.base = _resource_type
       AND sp.name = x.param_name
  ORDER BY weight
  )
  SELECT k.column1
  || string_agg(
    format(E'(fhirbase_json.json_get_in(%I.content, \'%s\'))[1]::text %s', lower(_resource_type), fhirbase_coll._rest(y.path)::text, y.direction)
    ,E', ')
  FROM with_meta y, (VALUES(E'\n ORDER BY ')) k -- we join for manadic effect, if no sorting parmas return null
  GROUP BY k.column1

func build_search_query(_resource_type text, _query text) RETURNS text
  -- TODO add to documentation
  -- custom sort param _sort:asc=a, _sort:desc=b => { _sort:["a:asc", "b:desc"] }
  WITH conds AS (
    SELECT
      this.build_cond(lower(resource_type),row(x.*))::text as cond,
      resource_type,
      chain,
      link_path,
      parent_resource
    FROM  this._expand_search_params(_resource_type, _query) x
  ), joins AS ( --TODO: what if no middle join present ie we have a.b.c.attr = x and no a.b.attr condition
    SELECT
      format(E'JOIN %I ON fhirbase_idx_fns.index_as_reference(%I.content, %L) && ARRAY[%I.logical_id]::text[] AND \n %s',
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
    FROM fhirbase_params._parse_param(_query)
    where key[1] ilike '_%'
  )

  SELECT
  fhirbase_gen._tpl('SELECT {{r}}.version_id, {{r}}.logical_id, {{r}}.resource_type, {{r}}.updated, {{r}}.published, {{r}}.category, {{r}}.content FROM {{r}}', 'r',  quote_ident(lower(_resource_type)))
  || E'\n' || COALESCE((SELECT string_agg(sql, E'\n')::text FROM joins), ' ')
  || E'\nWHERE '
  || COALESCE((SELECT string_agg(cond, ' AND ')
      FROM conds
      WHERE parent_resource IS NULL
      GROUP BY resource_type), ' true = true ')
  || COALESCE(this.build_sorting(_resource_type, _query), '')
  || format(E'\nLIMIT %s',COALESCE( (SELECT value::integer FROM special_params WHERE key = '_count'), '100'))
  || format(E'\nOFFSET %s',
    (
      COALESCE((SELECT value::integer FROM special_params WHERE key = '_page'), 0)::integer
      *
      COALESCE((SELECT value::integer FROM special_params WHERE key = '_count'), 1000)::integer
    ))

proc! search(_resource_type text, query text) RETURNS SETOF resource
  BEGIN
    RETURN QUERY EXECUTE this.build_search_query(_resource_type, query);

proc! explain_search(_resource_type text, query text) RETURNS table( "plan" text)
  BEGIN
    RETURN QUERY EXECUTE 'EXPLAIN ANALYZE ' || this.build_search_query(_resource_type, query);

func _search_entry(_cfg_ jsonb, _row_ "resource") RETURNS jsonb
  SELECT json_build_object('resource', _row_.content)::jsonb

func _search_bundle(_cfg_ jsonb, _entries_ jsonb) RETURNS jsonb
  SELECT json_build_object(
    'resourceType', 'Bundle',
    'type', 'searchset',
    'entry', _entries_
  )::jsonb

func fhir_search(_cfg_ jsonb, _type_ text, _params_ text) RETURNS jsonb
  WITH entry AS (
    SELECT this._search_entry(_cfg_, row(r.*)) as entry
      FROM this.search(_type_, _params_) r
  )
  SELECT this._search_bundle(
    _cfg_, (SELECT COALESCE(json_agg(entry),'[]'::json)::jsonb FROM entry)
  )
