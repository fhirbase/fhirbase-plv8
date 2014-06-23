CREATE OR REPLACE FUNCTION
_param_expression_string(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT CASE
    WHEN _modifier = '' THEN
      quote_ident(_table) || '.value ilike ' || quote_literal('%' || _value || '%')
    WHEN _modifier = 'exact' THEN
      quote_ident(_table) || '.value = ' || quote_literal(_value)
    END;
$$;

CREATE OR REPLACE FUNCTION
_param_expression_reference(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT
    '(' || quote_ident(_table) || '.logical_id = ' || quote_literal(_value) || ' OR ' || quote_ident(_table) || '.url = ' || quote_literal(_value) || ')' ||
    CASE WHEN _modifier <> '' THEN
      ' AND ' || quote_ident(_table) || '.resource_type = ' || quote_literal(_modifier)
    ELSE
      ''
    END;
$$;

CREATE OR REPLACE FUNCTION
_param_expression_quantity(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT
  quote_ident(_table) || '.value ' ||

  CASE
  WHEN op = '' OR op IS NULL THEN
    '= ' || quote_literal(p.val)
  WHEN op = '<' THEN
    '< ' || quote_literal(p.val)
  WHEN op = '>' THEN
    '>' || quote_literal(p.val)
  WHEN op = '~' THEN
    '<@ numrange(' || val - val * 0.05 || ',' || val + val * 0.05 || ')'
  ELSE
    '= "unknown operator: ' || op || '"'
  END ||

  CASE WHEN array_length(p.c, 1) = 3 THEN
    CASE WHEN p.c[2] IS NOT NULL AND p.c[2] <> '' THEN
      ' AND ' || quote_ident(_table) || '.system = ' || quote_literal(p.c[2])
    ELSE
      ''
    END ||
    CASE WHEN p.c[3] IS NOT NULL AND p.c[3] <> '' THEN
      ' AND ' || quote_ident(_table) || '.units = ' || quote_literal(p.c[3])
    ELSE
      ''
    END
  WHEN array_length(p.c, 1) = 1 THEN
    ''
  ELSE
    '"wrong number of compoments of search string, must be 1 or 3"'
  END
  FROM
  (SELECT
    regexp_split_to_array(_value, '\|') AS c,
    (regexp_matches(split_part(_value, '|', 1), '^(<|>|~)?'))[1] AS op,
    (regexp_matches(split_part(_value, '|', 1), '^(<|>|~)?(.+)$'))[2]::numeric AS val) p;
$$;

CREATE OR REPLACE FUNCTION
_param_expression_token(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  (SELECT
  CASE WHEN _modifier = '' THEN
    CASE WHEN p.count = 1 THEN
      quote_ident(_table) || '.code = ' || quote_literal(p.c1)
    WHEN p.count = 2 THEN
      quote_ident(_table) || '.code = ' || quote_literal(p.c2) || ' AND ' ||
      quote_ident(_table) || '.namespace = ' || quote_literal(p.c1)
    END
  WHEN _modifier = 'text' THEN
    quote_ident(_table) || '.text = ' || quote_literal(_value)
  ELSE
    '"unknown modifier' || _modifier || '"'
  END
  FROM
    (SELECT split_part(_value, '|', 1) AS c1,
     split_part(_value, '|', 2) AS c2,
     array_length(regexp_split_to_array(_value, '\|'), 1) AS count) p);
$$;

CREATE OR REPLACE FUNCTION
_param_expression_date(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT
  CASE WHEN op IS NULL THEN
    quote_literal(val) || '::tstzrange @> tstzrange(' || quote_ident(_table) || '."start", ' || quote_ident(_table) || '."end")'
  WHEN op = '>' THEN
    'tstzrange(' || quote_ident(_table) || '."start", ' || quote_ident(_table) || '."end") && ' || 'tstzrange(' || quote_literal(upper(val)) || ', NULL)'
  WHEN op = '<' THEN
    'tstzrange(' || quote_ident(_table) || '."start", ' || quote_ident(_table) || '."end") && ' || 'tstzrange(NULL, ' || quote_literal(lower(val)) || ')'
  ELSE
  '1'
  END
  FROM
  (SELECT
    (regexp_matches(_value, '^(<|>)?'))[1] AS op,
    convert_fhir_date_to_pgrange((regexp_matches(_value, '^(<|>)?(.+)$'))[2]) AS val) p;
$$;

CREATE OR REPLACE FUNCTION
param_expression(_resource_table varchar, _table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
WITH val_cond AS (SELECT
  CASE WHEN _type = 'string' THEN
    _param_expression_string(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'token' THEN
    _param_expression_token(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'date' THEN
    _param_expression_date(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'quantity' THEN
    _param_expression_quantity(_table, _param, _type, _modifier, regexp_split_to_table)
  WHEN _type = 'reference' THEN
    _param_expression_reference(_table, _param, _type, _modifier, regexp_split_to_table)
  ELSE 'implement_me' END as cond
  FROM regexp_split_to_table(_value, ','))
SELECT
  eval_template($SQL$
    ("{{tbl}}".param = {{param}}
     AND ({{vals_cond}}))
  $SQL$, 'tbl', _table
       , 'resource_table', _resource_table
       , 'param', quote_literal(_param)
       , 'vals_cond',
       (SELECT string_agg(cond, ' OR ') FROM val_cond));
$$;

-- forward declaration, actual function below
CREATE OR REPLACE FUNCTION
parse_search_params(_resource_type varchar, query jsonb, nested_level integer)
RETURNS text LANGUAGE sql AS $$
SELECT 'forward declaration'::text;
$$;

CREATE OR REPLACE FUNCTION
parse_search_params_one_level(_resource_type varchar, root_tbl varchar, query jsonb, nested_level integer)
RETURNS TABLE(joins text) LANGUAGE sql AS $$
    WITH search_params_not_aggregated AS (
      SELECT
        lower(_resource_type) || '_search_' || fri.search_type as tbl,
        lower(_resource_type) || '_' || x.key || '_idx_' || nested_level::varchar as alias,
        split_part(x.key, ':', 2) as modifier,
        param_name,
        search_type,
        key,
        value
      FROM jsonb_each_text(query) x
      JOIN fhir.resource_indexables fri
           ON fri.param_name = split_part(x.key, ':', 1)
           AND fri.resource_type =  _resource_type
      WHERE position('.' in x.key) = 0
    )
    SELECT
    'JOIN ' || z.tbl || ' ' || z.alias || ' ON ' || z.alias || '.resource_id::varchar = ' || root_tbl || '.logical_id::varchar AND ' ||
    string_agg(
      param_expression(root_tbl, z.alias, z.param_name, z.search_type, z.modifier, z.value), ' AND ') AS joins
    FROM search_params_not_aggregated z
    GROUP BY z.tbl, z.alias
$$;

CREATE OR REPLACE FUNCTION
parse_nested_search_params(_resource_table varchar, _resource_type varchar, query jsonb, nested_level integer)
RETURNS TABLE(joins text, weight integer) LANGUAGE sql AS $$
  WITH extracted_nested_query_params AS
    (SELECT
        _param_name, rest,
        (CASE WHEN array_length(re.ref_type, 1) = 1 THEN
          re.ref_type[1]
        ELSE
          split_part(_param_name, ':', 2)
        END) AS ref_type,
        val,
        array_last(ri.path) AS ref_attr
      FROM
        (SELECT
           (regexp_matches(x.key, '^([^.]+)\.'))[1] AS _param_name,
           (regexp_matches(x.key, '^([^.]+)\.(.+)'))[2] AS rest,
           x.value AS val
        FROM jsonb_each_text(query) x
        WHERE position('.' in x.key) > 0) x

      JOIN fhir.resource_indexables ri ON ri.param_name = split_part(_param_name, ':', 1) AND ri.resource_type = _resource_type
      JOIN fhir.resource_elements re ON re.path = ri.path)

  -- join through references
  SELECT
    eval_template($SQL$
    -- level {{nested_level}}
    JOIN {{refs_idx}} {{refs_alias}}
    ON   ({{refs_alias}}.logical_id)::varchar = ({{res_table}}.logical_id)::varchar
    AND  {{refs_alias}}.reference_type = {{ref_type}}
    $SQL$,
    'refs_idx', quote_ident(lower(_resource_type) || '_references'),
    'refs_alias', quote_ident(ref_attr || '_refs_' || nested_level),
    'res_table', quote_ident(_resource_table),
    'ref_type', quote_literal(ref_type),
    'nested_level', nested_level::varchar
    ) AS joins,
    1000 * nested_level + 0 as weight
  FROM
    extracted_nested_query_params x
  GROUP BY ref_type, ref_attr

  UNION (
    WITH new_queries AS (
    SELECT ref_type, ref_attr, keys_and_values_to_jsonb(array_agg(rest), array_agg(val)) as query
      FROM extracted_nested_query_params
      GROUP BY ref_type, ref_attr
    )
    -- search joins for this level
    SELECT parse_search_params_one_level(ref_type, quote_ident(ref_attr || '_refs_' || nested_level), query, nested_level) AS joins,
      1000 * nested_level + 1 as weight
    FROM new_queries

    -- recursively collect nested search params
    UNION
    SELECT
      (parse_nested_search_params(nq.ref_attr || '_refs_' || nested_level, nq.ref_type, nq.query, nested_level + 1)).joins,
      (parse_nested_search_params(nq.ref_attr || '_refs_' || nested_level, nq.ref_type, nq.query, nested_level + 1)).weight
    FROM new_queries nq
  )
$$;

CREATE OR REPLACE FUNCTION
parse_search_params(_resource_type varchar, query jsonb)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  resource_table varchar = 'main_resource_tbl';
  order_clause varchar = '';
BEGIN
  RETURN (
    SELECT
    eval_template($SQL$
      SELECT DISTINCT("{{resource_table_alias}}".logical_id)
        FROM {{resource_table}} "{{resource_table_alias}}"
        {{joins}}
        {{order_clause}}
    $SQL$,
    'resource_table_alias', resource_table,
    'resource_table', lower(_resource_type),
    'joins', string_agg(x.joins, E'\n'),
    'order_clause', order_clause)
    FROM
      (SELECT joins
       FROM
        (SELECT joins, 0 as weight
         FROM parse_search_params_one_level(_resource_type, 'main_resource_tbl', query, 0)

         UNION

         SELECT joins, weight
         FROM parse_nested_search_params('main_resource_tbl', _resource_type, query, 1)
       ) z
       ORDER BY weight
    ) x
  );
END
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
collect_included_logical_ids(includes varchar[], data jsonb)
RETURNS uuid[] LANGUAGE sql AS
$$
  SELECT ARRAY[]::uuid[];
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
search(resource_type varchar, query jsonb)
RETURNS TABLE (logical_id uuid, data jsonb, weight bigint, last_modified_date timestamptz, published timestamptz) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY EXECUTE (
      eval_template($SQL$
        WITH
        found_ids AS (
          SELECT logical_id,

          -- this will preserve final resources order
          ROW_NUMBER() OVER () as weight
          FROM ({{search_sql}}) AS x
        ),

        refs_to_include AS (
          SELECT reference_type AS type, logical_id AS id
          FROM "{{tbl}}_references" refs
          WHERE resource_id IN (SELECT logical_id FROM found_ids)
                AND path IN (SELECT * FROM
                             jsonb_array_elements_text({{json_includes}}::jsonb))
        )

        -- fetch found resources
        SELECT fres.logical_id, fres.data,
               fids.weight AS weight,
               fres.last_modified_date, fres.published
        FROM found_ids fids
        JOIN "{{tbl}}" fres ON fres.logical_id = fids.logical_id

        UNION

        -- union with included resources
        SELECT incres.logical_id, incres.data,
               0 AS weight, incres.last_modified_date, incres.published
        FROM resource incres WHERE incres.logical_id::varchar IN (SELECT id FROM refs_to_include)
                                   AND incres.resource_type IN (SELECT type FROM refs_to_include)

        ORDER BY weight
      $SQL$,
      'json_includes', quote_literal(COALESCE(query->'_include', '[]')),
      'tbl', LOWER(resource_type),
      'search_sql', COALESCE(
                       parse_search_params(resource_type, query),
                       ('SELECT logical_id FROM ' ||  LOWER(resource_type)))));
END
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
search_bundle(resource_type varchar, query jsonb)
RETURNS jsonb LANGUAGE sql AS $$
  SELECT
    json_build_object(
      'title', 'Search results for ' || query::varchar,
      'resourceType', 'Bundle',
      'updated', now(),
      'id', gen_random_uuid(),
      'entry', COALESCE(json_agg(z.*), '[]'::json)
    )::jsonb as json
  FROM
    (SELECT y.data AS content,
            y.last_modified_date AS updated,
            y.published AS published,
            y.logical_id AS id
     FROM search(resource_type, query) y) z
$$;
