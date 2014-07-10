--db:fhirb
--{{{


-- TODO: all by convetion
CREATE OR REPLACE
FUNCTION _param_expression(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar) RETURNS text
LANGUAGE sql AS $$
WITH val_cond AS (
  SELECT
  CASE WHEN _type = 'string' THEN
    _search_string_expression(_table, _param, _type, _modifier, y.value)
  WHEN _type = 'token' THEN
    _search_token_expression(_table, _param, _type, _modifier, y.value)
  WHEN _type = 'date' THEN
    _search_date_expression(_table, _param, _type, _modifier, y.value)
  WHEN _type = 'quantity' THEN
    _search_quantity_expression(_table, _param, _type, _modifier, y.value)
  WHEN _type = 'reference' THEN
    _search_reference_expression(_table, _param, _type, _modifier, y.value)
  WHEN _type = 'number' THEN
    _search_number_expression(_table, _param, _type, _modifier, y.value)
  ELSE 'implement_me' END as cond
  FROM _fhir_spilt_to_table(_value) y)
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

DROP FUNCTION IF EXISTS _expand_search_params(_resource_type text, _query jsonb);
CREATE
FUNCTION _expand_search_params(_resource_type text, _query jsonb)
RETURNS table (parent_res text, res text, path text[], key text, modifier text, value text)
LANGUAGE sql AS $$
  WITH RECURSIVE params(parent_res, res, path, key, modifier, value) AS (
    SELECT null::text as parent_res,
           _resource_type::text as res,
           ARRAY[_resource_type]::text[] as path,
           split_part(x.key,':',1) as key,
           split_part(x.key,':',2) as modifier,
           x.value
      FROM jsonb_each_text(_query) x
     WHERE split_part(x.key,':',1) NOT IN ('_tag', '_security', '_profile', '_sort')

    UNION

    SELECT res as parent_res,
           get_reference_type(split_part(x.key, '.', 1), re.ref_type) as res,
           array_append(x.path,split_part(key, '.', 1)) AS path,
           (regexp_matches(key, '^([^.]+)\.(.+)'))[2] AS key,
           split_part(split_part(x.key, '.', 1), ':',2) AS modifier,
           x.value
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
    WITH index_params AS (
     SELECT quote_ident(lower(p.res) || '_search_' || fri.search_type) as tbl,
            get_alias_from_path(array_append(p.path, fri.search_type::text)) AS als,
            get_alias_from_path(p.path) prnt,
            fri.param_name,
            fri.search_type,
            p.modifier,
            p.path,
            p.value
       FROM _expand_search_params(_resource_type, _query) p
       JOIN fhir.resource_indexables fri
         ON fri.param_name = p.key
        AND fri.resource_type =  p.res
      WHERE position('.' in p.key) = 0
    )
    SELECT _tpl($SQL$
            JOIN {{tbl}} {{als}}
              ON {{als}}.resource_id::varchar = {{prnt}}.logical_id::varchar
             AND {{cond}}
          $SQL$,
          'tbl',  p.tbl,
          'als',  p.als,
          'prnt', p.prnt,
          'cond', string_agg(
                     _param_expression(p.als,
                                       p.param_name,
                                       p.search_type,
                                       p.modifier,
                                       p.value), ' AND ')) as join_str
           ,p.path::text || '2' as weight
       FROM index_params p
       WHERE p.modifier <> 'missing'
       GROUP BY p.tbl, p.als, p.prnt, p.path, p.search_type
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION build_search_missing_parts(_resource_type text, _query jsonb)
RETURNS table (part text, sql text)
LANGUAGE sql AS $$
    WITH index_params AS (
     SELECT quote_ident(lower(p.res) || '_search_' || fri.search_type) as tbl,
            get_alias_from_path(array_append(p.path, fri.search_type::text)) AS als,
            get_alias_from_path(p.path) prnt,
            p.modifier,
            fri.param_name,
            p.value
       FROM _expand_search_params(_resource_type, _query) p
       JOIN fhir.resource_indexables fri
         ON fri.param_name = p.key
        AND fri.resource_type =  p.res
      WHERE position('.' in p.key) = 0
        AND p.modifier = 'missing'
    )
    SELECT 'JOIN'::text,
           _tpl($SQL$
             LEFT JOIN {{tbl}} {{als}}
                  ON {{als}}.resource_id::varchar = {{prnt}}.logical_id::varchar
                 AND {{als}}.param = {{param_name}}
           $SQL$,
           'tbl',  p.tbl,
           'als',  p.als,
           'prnt', p.prnt,
           'param_name', quote_literal(p.param_name))
       FROM index_params p
   UNION
   SELECT 'WHERE'::text,
     p.als || '.resource_id IS ' ||
     CASE WHEN p.value = 'true' THEN 'NULL ' ELSE 'NOT NULL' END
     FROM index_params p
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _ids_expression(_tbl_ text, ids text) RETURNS text -- sql
LANGUAGE sql AS $$
SELECT CASE
    WHEN ids IS NULL THEN '(true = true)'
    ELSE
      (
        SELECT ' ( ' || string_agg(y.exp,' OR ') || ')' FROM (
          SELECT _tbl_ || '.logical_id=' || quote_literal(x) AS exp
           FROM regexp_split_to_table(ids, ',') x
        ) y
      )
    END
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _build_references_joins(_resource_type text, _query jsonb)
RETURNS table (sql text, weight text)
LANGUAGE sql AS $$
   WITH params AS (
      SELECT * FROM _expand_search_params(_resource_type, _query)
   )
    -- joins trhough referenced resources for chained params
    SELECT _tpl($SQL$
            JOIN {{tbl}} {{als}}
              ON {{als}}.resource_id::varchar = {{prnt}}.logical_id::varchar
              {{ids}}
           $SQL$,
           'tbl', quote_ident(lower(p.parent_res) || '_references'),
           'als', get_alias_from_path(p.path),
           'prnt', get_alias_from_path(_butlast(p.path)),
           'ids', CASE WHEN ids.value IS NOT NULL THEN ' AND ' || _ids_expression(get_alias_from_path(p.path), ids.value) ELSE '' END)
        AS join_str
           ,p.path::text || '1'  as weight
      FROM params p
 LEFT JOIN params ids ON ids.key = '_id' AND ids.path = p.path AND ids.parent_res = p.parent_res AND ids.res = p.res
     WHERE p.parent_res IS NOT NULL
  GROUP BY p.parent_res, p.res, p.path, ids.value
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
               y.value as value
          FROM jsonb_each_text(_query) x,
               _fhir_spilt_to_table(x.value) y
         WHERE split_part(x.key,':',1) IN ('_tag', '_security', '_profile')
      ) y
      GROUP BY y.als, y.key, y.modifier
$$ IMMUTABLE;


CREATE OR REPLACE
FUNCTION build_search_joins(_resource_type text, _query jsonb) RETURNS text
LANGUAGE sql AS $$
  WITH joins AS  (
    SELECT * FROM _build_tags_joins(_resource_type, _query)
    UNION ALL
    SELECT * FROM _build_references_joins(_resource_type, _query)
    UNION ALL
    SELECT * FROM _build_index_joins(_resource_type, _query)
  )
  -- agg to SQL string
  SELECT string_agg(sql, '')
    FROM (SELECT sql  FROM joins ORDER BY weight) _ ;
$$;

CREATE OR REPLACE
FUNCTION build_search_part(_resource_type varchar, query jsonb) RETURNS table(part text, sql text)
LANGUAGE sql AS $$
  SELECT 'JOIN'::text, build_search_joins(_resource_type, query)
  UNION ALL
  SELECT * FROM build_search_missing_parts(_resource_type, query)
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
   -- we do not sort by chained params
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
           string_agg(str, ', ')
         ELSE
           ' updated DESC '
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
FUNCTION build_offset_part(_resource_type varchar, query jsonb) RETURNS table(part text, sql text)
LANGUAGE sql AS $$
  SELECT 'OFFSET'::text, (COALESCE(query->>'_page', '0')::integer)::text;
$$;

CREATE OR REPLACE
FUNCTION build_limit_part(_resource_type varchar, query jsonb) RETURNS table(part text, sql text)
LANGUAGE sql AS $$
  SELECT 'LIMIT'::text, (COALESCE(query->>'_count', '100')::integer)::text;
$$;

CREATE OR REPLACE
FUNCTION build_order_part(_resource_type varchar, query jsonb) RETURNS table(part text, sql text)
LANGUAGE sql AS $$
  SELECT 'JOIN'::text, build_order_joins(_resource_type, query)
  UNION
  SELECT 'ORDER'::text, build_order_clause(_resource_type, query)
  UNION
  SELECT 'SELECT'::text, lower(_resource_type) || '_' || param || '_order_idx.' || CASE WHEN direction = 'ASC' THEN 'lower' ELSE 'upper' END
    FROM parse_order_params(_resource_type, query)
$$;

CREATE OR REPLACE
FUNCTION build_ids_search_part(_resource_type varchar, query jsonb) RETURNS table(part text, sql text)
LANGUAGE sql AS $$
  SELECT 'WHERE'::text, _ids_expression(quote_ident(lower(_resource_type)), query->>'_id')
$$;

CREATE OR REPLACE
FUNCTION build_select_part(_resource_type varchar, query jsonb) RETURNS table(part text, sql text)
LANGUAGE sql AS $$
  SELECT 'SELECT'::text, quote_ident(lower(_resource_type)) || '.' || x as sql
    FROM unnest('{logical_id,version_id,content, category, updated, published, resource_type}'::text[]) x
$$;


-- TODO add to documentation
-- custom sort param _sort:asc=a, _sort:desc=b => { _sort:["a:asc", "b:desc"] }
CREATE OR REPLACE
FUNCTION build_search_query(_resource_type varchar, query jsonb) RETURNS text
LANGUAGE sql AS $$
-- we get query jsonb and return query sql string
-- i.e. we build query
-- build is complex, so we split it into parts (i.e. search part, chain part, order part, ids part)
-- query is represented as simple relation table(query_part enum, sql text), where query_part one of SELECT, JOIN, WHERE, ORDER, LIMIT
-- for example build_paging_part(query) => [('LIMIT', 100), ('OFFSET', 50)]
-- then we union all parts and generate SQL string
  WITH sql_query AS (
    SELECT * FROM build_select_part(_resource_type, query)
    UNION
    SELECT * FROM build_search_part(_resource_type, query)
    UNION
    SELECT * FROM build_ids_search_part(_resource_type, query)
    UNION
    SELECT * FROM build_order_part(_resource_type, query)
    UNION
    SELECT * FROM build_offset_part(_resource_type, query)
    UNION
    SELECT * FROM build_limit_part(_resource_type,query)
  )
  SELECT
  _tpl($SQL$
    SELECT DISTINCT {{select}}
      FROM {{tbl}} {{tbl}}
      {{join}}
      WHERE {{where}}
      ORDER BY {{order}}
      LIMIT {{limit}}
      OFFSET {{offset}}
  $SQL$,
  'tbl',   quote_ident(lower(_resource_type)),
  'select', (SELECT string_agg(DISTINCT(sql), E'\n,')  FROM sql_query WHERE part = 'SELECT' and sql IS NOT NULL),
  'join',   (SELECT string_agg(sql, E'\n')   FROM sql_query WHERE part = 'JOIN' and sql IS NOT NULL),
  'where',  COALESCE((SELECT string_agg(sql, ' AND ') FROM sql_query WHERE part = 'WHERE' and sql IS NOT NULL), ' true = true'),
  'order',  COALESCE((SELECT string_agg(sql, ' , ') FROM sql_query WHERE part = 'ORDER' and sql IS NOT NULL), ' updated:desc '),
  'limit',  (SELECT sql FROM sql_query WHERE part = 'LIMIT' limit 1),
  'offset', (SELECT sql FROM sql_query WHERE part = 'OFFSET' limit 1)
  );
$$;


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
