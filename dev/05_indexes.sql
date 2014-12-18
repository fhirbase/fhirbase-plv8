--db:fhirb
--{{{
CREATE EXTENSION IF NOT EXISTS btree_gist ;

CREATE OR REPLACE
FUNCTION _token_index_fn(dtype varchar, is_primitive boolean) RETURNS text
LANGUAGE sql AS $$
SELECT  'index_' || CASE WHEN is_primitive THEN 'primitive' ELSE lower(dtype::varchar) END || '_as_token'
$$ IMMUTABLE;

--}}}
--{{{
-- index token
CREATE OR REPLACE
FUNCTION index_resource(_resource text)
RETURNS bigint
LANGUAGE sql AS $$
SELECT sum(count)::bigint FROM (
  SELECT
  count(
    _eval(
      _tpl(
        $SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIN ({{idx_fn}}(content,'{{path}}')) $SQL$,
        'tbl', quote_ident(lower(resource_type))
        ,'tp', lower(search_type)
        ,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_token_idx')::varchar,'-','_')
        ,'path', _rest(path)::varchar
        ,'idx_fn', (SELECT _token_index_fn(type, is_primitive))
  )))
  from fhir.resource_indexables
  where search_type = 'token'
  and resource_type = _resource

  UNION
  -- index string
  SELECT
  count(
    _eval(
      _tpl(
        $SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIN (index_as_string(content,'{{path}}'::text[]) gin_trgm_ops) $SQL$,
        'tbl', quote_ident(lower(resource_type))
        ,'tp', lower(search_type)
        ,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_token_idx')::varchar,'-','_')
        ,'path', _rest(path)::varchar
        ,'dtp', CASE WHEN is_primitive THEN 'primitive' ELSE lower(type::varchar) END
  )))
  from fhir.resource_indexables
  where search_type = 'string'
  and resource_type = _resource
  -- index reference
  UNION
  SELECT
  count(
    _eval(
      _tpl(
        $SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIN (index_as_reference(content,'{{path}}')) $SQL$,
        'tbl', quote_ident(lower(resource_type))
        ,'tp', lower(search_type)
        ,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_token_idx')::varchar,'-','_')
        ,'path', _rest(path)::varchar
        ,'idx_fn', (SELECT _token_index_fn(type, is_primitive))
  )))
  from fhir.resource_indexables
  where search_type = 'reference'
  and resource_type = _resource
  UNION
  --index date
  SELECT
  count(_eval(
      _tpl(
        $SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIST (index_as_date(content,'{{path}}'::text[], '{{tp}}') range_ops) $SQL$,
        'tbl', quote_ident(lower(resource_type))
        ,'tp', type
        ,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '__date_idx')::varchar,'-','_')
        ,'path', _rest(path)::varchar
        ,'idx_fn', (SELECT _token_index_fn(type, is_primitive))
      )
  ))
  from fhir.resource_indexables
  where search_type = 'date'
  and resource_type = _resource
) _

$$;
--}}}

--{{{
CREATE OR REPLACE
FUNCTION drop_indexes(_resource text)
RETURNS bigint
LANGUAGE sql AS $$
  SELECT count(_eval(format('DROP INDEX IF EXISTS "%s"',indname)))
  FROM (
      SELECT i.relname as indname,
      i.relowner as indowner,
      idx.indrelid::regclass,
      am.amname as indam,
      idx.indkey,
      ARRAY(
        SELECT pg_get_indexdef(idx.indexrelid, k + 1, true)
        FROM generate_subscripts(idx.indkey, 1) as k
        ORDER BY k
      ) as indkey_names,
      idx.indexprs IS NOT NULL as indexprs,
      idx.indpred IS NOT NULL as indpred
      FROM   pg_index as idx
      JOIN   pg_class as i
      ON     i.oid = idx.indexrelid
      JOIN   pg_am as am
      ON     i.relam = am.oid
      WHERE
      idx.indrelid::regclass = quote_ident(lower(_resource))::regclass
      and i.relname ilike '%_idx'
  ) idx;
$$ IMMUTABLE;
--}}}

--{{{
SELECT index_resource(resource_type) FROM (
  select DISTINCT resource_type
  from fhir.resource_indexables
) _
--}}}
