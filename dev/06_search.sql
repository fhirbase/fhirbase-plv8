--db:fhirb
--{{{

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
      format('index_as_string(content, %L) ilike %L',
        _rest(fr.path),
        '%' || (q->>'value') || '%')
     WHEN fr.search_type = 'token' THEN
      format('%s(content, %L) && ARRAY[%L]::varchar[]',
          _token_index_fn(fr.type, fr.is_primitive),
          _rest(fr.path),
          q->>'value')
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

/* SELECT build_search_query('Patient', _parse_param('name=john&name=anna&identifier=MRN|777')); */

--}}}
--{{{

DROP FUNCTION search(_resource_type text, query text);
CREATE FUNCTION
search(_resource_type text, query text)
RETURNS TABLE (logical_id uuid, version_id uuid, content jsonb)
LANGUAGE plpgsql AS $$
BEGIN
RETURN QUERY EXECUTE (
  _tpl($SQL$
    SELECT logical_id, version_id, content FROM (
     {{search_sql}}
    )_
  $SQL$,
  'tbl',           lower(_resource_type),
  'search_sql',    build_search_query(_resource_type, _parse_param(query))));
END
$$ IMMUTABLE;

/* \timing */
/* SELECT content#>>'{name}' FROM */
/* search('Patient', 'name=john'); */
--}}}
