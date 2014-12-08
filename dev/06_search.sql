--db:fhirb
--{{{
CREATE OR REPLACE
FUNCTION build_string_cond(fr fhir.resource_indexables, param jsonb)
RETURNS text
LANGUAGE sql AS $$
SELECT '(' || string_agg(
  format('index_as_string(content, %L) ilike %L',
      _rest(fr.path), '%' || x || '%'),
    ' OR ') || ')'
FROM regexp_split_to_table(param->>'value', ',') x
$$;

CREATE OR REPLACE
FUNCTION build_token_cond(fr fhir.resource_indexables, param jsonb)
RETURNS text
LANGUAGE sql AS $$
SELECT
  format('%s(content, %L) && %L::varchar[]',
    _token_index_fn(fr.type, fr.is_primitive),
    _rest(fr.path),
    regexp_split_to_array(param->>'value', ','))
$$;

CREATE OR REPLACE
FUNCTION build_where_part(_resource_type varchar, query jsonb) RETURNS text
LANGUAGE sql AS $$
WITH queries AS (
  SELECT jsonb_array_elements as q
  FROM jsonb_array_elements(query)
),
params AS (
  SELECT
  CASE
  WHEN fr.search_type = 'string' THEN
    build_string_cond(fr.*,q)
  WHEN fr.search_type = 'token' THEN
    build_token_cond(fr.*,q)
  END as cnd
  FROM queries
  JOIN fhir.resource_indexables fr
  ON lower(fr.resource_type) = lower(_resource_type)
  AND fr.param_name = q->>'param'
)
SELECT string_agg(cnd, E' \nAND ')
FROM params
$$;

-- TODO add to documentation
-- custom sort param _sort:asc=a, _sort:desc=b => { _sort:["a:asc", "b:desc"] }
CREATE OR REPLACE
FUNCTION build_search_query(_resource_type varchar, query jsonb) RETURNS text
LANGUAGE sql AS $$
SELECT
_tpl($SQL$
  SELECT * FROM {{tbl}}
  WHERE
  {{cond}}
  --ORDER BY {{order}}
  LIMIT {{limit}}
  OFFSET {{offset}}
  $SQL$,
  'tbl', lower(_resource_type)
  ,'cond', (SELECT build_where_part(_resource_type, query))
  ,'limit', '10'
  ,'offset', '0'
);
$$;


DROP FUNCTION IF EXISTS search(_resource_type text, query text);
CREATE FUNCTION
search(_resource_type text, query text)
RETURNS TABLE (logical_id uuid, version_id uuid, content jsonb)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY EXECUTE (
    _tpl($SQL$
      SELECT logical_id, version_id, content FROM (
        {{search_sql}}
      ) _
    $SQL$,
    'tbl',           lower(_resource_type),
    'search_sql',    build_search_query(_resource_type, _parse_param(query))));
END
$$ IMMUTABLE;

--}}}
