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
CREATE OR REPLACE
FUNCTION index_token_exp(_meta fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
  SELECT
   format(
    'CREATE INDEX %I ON %I USING GIN (%s(content,%L))'
    , replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
    , lower(_meta.resource_type)
    , _token_index_fn(_meta.type, _meta.is_primitive)
    , _rest(_meta.path)::varchar
   )
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION index_reference_exp(_meta fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
  SELECT
    format(
      'CREATE INDEX %I ON %I USING GIN (index_as_reference(content,%L))'
      ,replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
      ,lower(_meta.resource_type)
      ,_rest(_meta.path)::varchar
    )
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION index_string_exp(_meta fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIN (index_as_string(content,%L::text[]) gin_trgm_ops)'
      ,replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
      ,lower(_meta.resource_type)
      ,_rest(_meta.path)::varchar
    )
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION index_date_exp(_meta fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIST (index_as_date(content,%L::text[], %L) range_ops)'
      ,replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
      ,lower(_meta.resource_type)
      ,_rest(_meta.path)::varchar
      ,_meta.type
    )
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION index_search_param_exp(x fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
 SELECT
 CASE
   WHEN x.search_type = 'token' THEN index_token_exp(x)
   WHEN x.search_type = 'reference' THEN index_reference_exp(x)
   WHEN x.search_type = 'string' THEN index_string_exp(x)
   WHEN x.search_type = 'date' THEN index_string_exp(x)
   ELSE ''
 END
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION index_search_param(_resource_type text, _param_name text)
RETURNS text
LANGUAGE sql AS $$
  SELECT count(_eval(index_search_param_exp(ROW(x.*))))::text
  FROM fhir.resource_indexables x
  WHERE resource_type = _resource_type
  AND  param_name = _param_name
$$ IMMUTABLE;
--}}}


--{{{
-- index token
CREATE OR REPLACE
FUNCTION index_resource(_resource text)
RETURNS table (idx text)
LANGUAGE sql AS $$
  SELECT
  _eval(index_search_param_exp(ROW(x.*)))
  from fhir.resource_indexables x
  where search_type IN ('token', 'reference', 'string', 'date')
  and resource_type = _resource
$$;

CREATE OR REPLACE
FUNCTION index_all_resources()
RETURNS table (idx text)
LANGUAGE sql AS $$
  SELECT
  _eval(index_search_param_exp(ROW(x.*)))
  from fhir.resource_indexables x
  where search_type IN ('token', 'reference', 'string', 'date')
$$;

SELECT index_all_resources();
--}}}

--{{{
CREATE OR REPLACE
FUNCTION drop_resource_indexes(_resource text)
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
