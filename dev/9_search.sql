--db:fhirb
--{{{
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

-- TODO: all by convetion
CREATE OR REPLACE FUNCTION
param_expression(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
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
    ({{tbl}}.param = {{param}}
     AND ({{vals_cond}}))
  $SQL$, 'tbl', quote_ident(_table)
       , 'param', quote_literal(_param)
       , 'vals_cond',
       (SELECT string_agg(cond, ' OR ') FROM val_cond));
$$;


CREATE OR REPLACE
FUNCTION get_reference_type(_key text,  _types text[])
RETURNS text language sql AS $$
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
FUNCTION get_alias_from_path( _path text[])
RETURNS text language sql AS $$
    SELECT
      regexp_replace(
       lower(array_to_string(_path, '_')),
       E'\\W', '') ;
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
_param_expression_tag(_table varchar, _key varchar, _val varchar, _modifier varchar)
RETURNS text LANGUAGE sql AS $$
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
    _table || '.label ilike ' || quote_literal('%' || _val || '%')
  WHEN _modifier = 'partial' THEN
    _table || '.term  ilike ' || quote_literal(_val || '%')
  ELSE
    _table || '.term = ' || quote_literal(_val)
  END
  || ')';
$$;

CREATE OR REPLACE FUNCTION
build_search_joins(_resource_type text, _query jsonb)
RETURNS text LANGUAGE sql AS $$

-- recursivelly expand chained params
WITH RECURSIVE params(parent_res, res, path, key, value) AS (

  SELECT null::text as parent_res,
         _resource_type::text as res,
         ARRAY[_resource_type]::text[] as path,
         x.key,
         x.value
    FROM jsonb_each_text(_query) x
   WHERE split_part(x.key,':',1) NOT IN ('_tag', '_security', '_profile')

  UNION

  SELECT res as parent_res,
         get_reference_type(split_part(x.key, '.', 1), re.ref_type) as res,
         array_append(x.path,split_part(key, '.', 1)) as path,
         (regexp_matches(key, '^([^.]+)\.(.+)'))[2] AS key,
         value
         FROM params x
   JOIN  fhir.resource_indexables ri
     ON  ri.param_name = split_part(split_part(x.key, '.', 1), ':',1)
    AND  ri.resource_type = x.res
   JOIN  fhir.resource_elements re
     ON  re.path = ri.path
),
search_index_joins AS (
  -- joins for index search
  SELECT eval_template($SQL$
          JOIN {{tbl}} {{als}}
            ON {{als}}.resource_id::varchar = {{prnt}}.logical_id::varchar
            AND {{cond}}
        $SQL$,
        'tbl',  quote_ident(lower(p.res) || '_search_' || fri.search_type),
        'als',  get_alias_from_path(array_append(p.path, fri.search_type::text)),
        'prnt', get_alias_from_path(p.path),
        'cond', string_agg(
                   param_expression( get_alias_from_path(array_append(p.path, fri.search_type::text)),
                                     fri.param_name,
                                     fri.search_type,
                                     split_part(p.key, ':', 2),
                                     p.value), ' AND ')) as join_str
         ,p.path::text || '2' as weight
     FROM params p
     JOIN fhir.resource_indexables fri
       ON fri.param_name = split_part(p.key, ':', 1)
      AND fri.resource_type =  p.res
    WHERE position('.' in p.key) = 0
    GROUP BY p.res, p.path, fri.search_type
),
references_joins AS (
  -- joins trhough referenced resources for chained params
  SELECT eval_template($SQL$
          JOIN {{tbl}} {{als}}
            ON {{als}}.resource_id::varchar = {{prnt}}.logical_id::varchar
         $SQL$,
         'tbl', quote_ident(lower(p.parent_res) || '_references'),
         'als', get_alias_from_path(p.path),
         'prnt', get_alias_from_path(butlast(p.path)))
         AS join_str
          ,p.path::text || '1'  as weight
    FROM params p
    WHERE parent_res is not null
    GROUP BY p.parent_res, res, path
),
tag_joins AS (
  SELECT eval_template($SQL$
          JOIN {{tbl}} {{als}}
            ON {{als}}.resource_id = {{prnt}}.logical_id
           AND {{cond}}
         $SQL$,
         'tbl', lower(_resource_type || '_tag'),
         'als',  y.als,
         'cond', string_agg(_param_expression_tag(y.als, y.key, y.value, y.modifier), ' OR '),
         'prnt', quote_ident(lower(_resource_type)))
          as join_str,
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
),
-- mix joins together
joins AS  (
  SELECT join_str, weight FROM tag_joins
  UNION ALL
  SELECT * FROM search_index_joins
  UNION ALL
  SELECT * FROM references_joins
)
-- agg to SQL string
SELECT string_agg(join_str, '')
  FROM (SELECT join_str  FROM joins ORDER BY weight LIMIT 1000) _ ;
$$;

CREATE OR REPLACE FUNCTION
build_order_by(_resource_type varchar, query jsonb)
RETURNS text LANGUAGE sql AS $$
 select ''::text;
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
build_search_query(_resource_type varchar, query jsonb)
RETURNS text LANGUAGE sql AS $$
  SELECT COALESCE(
    eval_template($SQL$
      SELECT {{tbl}}.*
        FROM {{tbl}} {{tbl}}
        {{joins}}
        {{order_clause}}
    $SQL$,
    'tbl', quote_ident(lower(_resource_type)),
    'joins', build_search_joins(_resource_type, query),
    'order_clause', ''),

   ('SELECT logical_id FROM ' ||  LOWER(_resource_type)));
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS search(character varying,jsonb);
CREATE OR REPLACE FUNCTION
search(_resource_type varchar, query jsonb)
RETURNS TABLE (resource_type varchar, logical_id uuid, data jsonb, last_modified_date timestamptz, published timestamptz, weight bigint)
LANGUAGE plpgsql AS $$
BEGIN
RETURN QUERY EXECUTE (
  eval_template($SQL$
    WITH
    found_resources AS (
      SELECT x.resource_type,
             x.logical_id,
             x.data,
             x.last_modified_date,
             x.published,
             ROW_NUMBER() OVER () as weight
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
             incres.data,
             incres.last_modified_date,
             incres.published,
             0 AS weight
        FROM resource incres, refs_to_include
       WHERE incres.logical_id::varchar = refs_to_include.id
         AND incres.resource_type = refs_to_include.type
    )

    SELECT * from found_resources
    UNION
    SELECT * from included_resources
    ORDER BY weight

  $SQL$,
  'json_includes', quote_literal(COALESCE(query->'_include', '[]')),
  'tbl',           LOWER(_resource_type),
  'search_sql',    build_search_query(_resource_type, query)));
END
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS search_bundle(_resource_type varchar, query jsonb);
CREATE OR REPLACE FUNCTION
search_bundle(_resource_type varchar, query jsonb)
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
            y.logical_id AS id,
            CASE WHEN string_agg(t.scheme,'') IS NULL THEN
              '[]'::jsonb
              ELSE
            json_agg(
               json_build_object('scheme', t.scheme,
                                 'term', t.term,
                                 'label', t.label))::jsonb
            END AS category
       FROM search(_resource_type, query) y
  LEFT JOIN tag t
         ON t.resource_id = y.logical_id
            AND t.resource_type = y.resource_type
   GROUP BY y.logical_id,
            y.data,
            y.last_modified_date,
            y.published
    ) z
$$;
--}}}
--{{{

WITH params AS (
    SELECT lower('Patient') as prnt,
           lower('Patient' || '_sort') as tbl,
           lower('Patient' || '_sort_' || fri.param_name) as als,
           fri.param_name,
           fri.search_type,
           split_part(y.value,':',2) as direction
      from jsonb_each('{"_sort":["name:asc", "birthdate:desc"]}') x,
           jsonb_array_elements_text(x.value) y,
           fhir.resource_indexables fri
    WHERE split_part(x.key, ':',1) = '_sort'
      AND fri.param_name = split_part(y.value,':',1)
      AND fri.resource_type = 'Patient' ),
joins AS (
  SELECT  eval_template($SQL$
            JOIN {{tbl}} {{als}}
              ON {{als}}.resource_id = {{prnt}}.logical_id
          $SQL$, 'tbl', tbl, 'als', als, 'prnt', prnt) as join_str
     FROM params)
SELECT (select string_agg(j.join_str, ', ') from joins j);

--}}}
