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
    ("{{resource_table}}".logical_id = "{{tbl}}".resource_id
     AND "{{tbl}}".param = {{param}}
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
parse_nested_search_params(_resource_table varchar, _resource_type varchar, query jsonb, nested_level integer)
RETURNS setof text LANGUAGE sql AS $$
SELECT
  'split_part(' || _resource_table || '.data->' || quote_literal(ref_attr) || '->>''reference'', ''/'', 2)::uuid IN (' ||
  parse_search_params(ref_type, keys_and_values_to_jsonb(array_agg(rest), array_agg(val)), nested_level + 1) ||
  ')'
FROM
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
  JOIN fhir.resource_elements re ON re.path = ri.path) x
GROUP BY ref_type, ref_attr
$$;

CREATE OR REPLACE FUNCTION
parse_search_params(_resource_type varchar, query jsonb, nested_level integer)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  resource_table varchar = _resource_type || '_resource_' || nested_level;
BEGIN
  RETURN (SELECT
      eval_template($SQL$
        SELECT DISTINCT("{{resource_table}}".logical_id)
          FROM {{tables}}
          {{idx_conds}}
      $SQL$,
      'resource_table', resource_table,
      'tables',
      tables_with_aliases(array[lower(_resource_type)]::varchar[]  || array_agg(z.tbl)::varchar[],
                          array[resource_table]::varchar[] || array_agg(z.alias)::varchar[]),
      'idx_conds', CASE WHEN length(string_agg(z.cond, '')) > 0 THEN
                     'WHERE ' || string_agg(z.cond, '  AND  ')
                   ELSE
                     ''
                   END)

      FROM (
      SELECT
         z.tbl
        ,z.alias
        ,string_agg(
          param_expression(resource_table, z.alias, z.param_name, z.search_type, z.modifier, z.value)
          , ' AND ') as cond
        FROM (
          SELECT
            lower(_resource_type) || '_search_' || fri.search_type as tbl
            ,lower(_resource_type) || '_' || x.key || '_idx' as alias
            ,split_part(x.key, ':', 2) as modifier
            ,param_name, search_type, key, value
           FROM jsonb_each_text(query) x
           JOIN fhir.resource_indexables fri
               ON fri.param_name = split_part(x.key, ':', 1)
               AND fri.resource_type =  _resource_type
           WHERE position('.' in x.key) = 0
        ) z
        GROUP BY tbl, alias

        -- nested params
        UNION
        SELECT
          NULL as tbl,
          NULL as alias,
          string_agg("parse_nested_search_params", ' AND ') as cond
          FROM parse_nested_search_params(resource_table, _resource_type, query, nested_level)
        WHERE "parse_nested_search_params" IS NOT NULL
      ) z);
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
RETURNS TABLE (logical_id uuid, data jsonb) LANGUAGE plpgsql AS $$
DECLARE
  includes varchar[];
  inc record;
BEGIN
  SELECT INTO includes COALESCE(array_agg(jsonb_array_elements_text), '{}'::varchar[])
  FROM jsonb_array_elements_text(query->'_include');

  RETURN QUERY EXECUTE (
        eval_template($SQL$

        WITH found_resources AS (
          SELECT logical_id, data
          FROM "{{tbl}}" x
          WHERE logical_id IN ({{search_sql}})),

        refs_to_include AS (
          SELECT reference_type AS type, reference_id AS id
          FROM "{{tbl}}_references" refs
          WHERE logical_id IN (SELECT logical_id FROM found_resources)
                AND path = ANY({{includes}}::varchar[])
        )

        -- fetch found resources
        SELECT fres.logical_id, fres.data
        FROM found_resources fres

        UNION

        -- union with included resources
        SELECT incres.logical_id, incres.data
        FROM resource incres WHERE incres.logical_id::varchar IN (SELECT id FROM refs_to_include)
                                   AND incres.resource_type IN (SELECT type FROM refs_to_include)
      $SQL$,
      'includes', quote_literal(includes),
      'tbl', lower(resource_type),
      'search_sql', coalesce(
                       parse_search_params(resource_type, query, 1),
                       ('SELECT logical_id FROM ' || lower(resource_type)))));
END
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
search_resource(resource_type varchar, query jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  res record;
BEGIN
  EXECUTE
    eval_template($SQL$
      WITH entries AS
      (SELECT
        x.logical_id as id
        ,x.last_modified_date as last_modified_date
        ,x.published as published
        ,x.data as content
        FROM "{{tbl}}" x
        WHERE logical_id IN ({{search_sql}}))
      SELECT
        json_build_object(
          'title', 'search',
          'resourceType', 'Bundle',
          'updated', now(),
          'id', gen_random_uuid(),
          'entry', COALESCE(json_agg(y.*), '[]'::json)
        ) as json
        FROM entries y
   $SQL$,
  'tbl', lower(resource_type),
  'search_sql', coalesce(
                   parse_search_params(resource_type, query, 1),
                   ('SELECT logical_id FROM ' || lower(resource_type))))
  INTO res;

  RETURN res.json;
END
$$;

CREATE OR REPLACE FUNCTION
history_resource(_resource_type varchar, _id uuid)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  res record;
BEGIN
  EXECUTE
    eval_template($SQL$
      WITH entries AS
      (SELECT
          x.logical_id as id
          ,x.last_modified_date as last_modified_date
          ,x.published as published
          ,x.data as content
        FROM "{{tbl}}" x
        WHERE x.logical_id  = $1
        UNION
        SELECT
          x.logical_id as id
          ,x.last_modified_date as last_modified_date
          ,x.published as published
          ,x.data as content
        FROM {{tbl}}_history x
        WHERE x.logical_id  = $1)
      SELECT
        json_build_object(
          'title', 'search',
          'resourceType', 'Bundle',
          'updated', now(),
          'id', gen_random_uuid(),
          'entry', COALESCE(json_agg(y.*), '[]'::json)
        ) as json
        FROM entries y
   $SQL$, 'tbl', lower(_resource_type))
  INTO res USING _id;

  RETURN res.json;
END
$$;
