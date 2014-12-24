--db:fhirb
--db:fhirplace
--{{{
CREATE EXTENSION IF NOT EXISTS btree_gist ;

CREATE OR REPLACE
FUNCTION _token_index_fn(dtype varchar, is_primitive boolean) RETURNS text
LANGUAGE sql AS $$
SELECT  'index_' || CASE WHEN is_primitive THEN 'primitive' ELSE lower(dtype::varchar) END || '_as_token'
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _index_name(_meta fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
    SELECT replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' ||  _last(_meta.path) || '_' || _meta.search_type || '_idx')::varchar,'-','_')
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION index_token_exp(_meta fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
  SELECT
   format(
    'CREATE INDEX %I ON %I USING GIN (%s(content,%L))'
    , _index_name(_meta)
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
      ,_index_name(_meta)
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
      ,_index_name(_meta)
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
      ,_index_name(_meta)
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
   WHEN x.search_type = 'date' THEN index_date_exp(x)
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

CREATE OR REPLACE
FUNCTION drop_index_search_param_exp(_meta fhir.resource_indexables)
RETURNS text
LANGUAGE sql AS $$
  SELECT format('DROP INDEX IF EXISTS %I',_index_name(_meta))
$$;

-- TODO: implement for symmetric api
CREATE OR REPLACE
FUNCTION drop_index_search_param(_resource_type text, _param_name text)
RETURNS bigint
LANGUAGE sql AS $$
  SELECT count(_eval(drop_index_search_param_exp(ROW(x.*))))
  FROM fhir.resource_indexables x
  WHERE resource_type = _resource_type
  AND  param_name = _param_name
$$;

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

CREATE OR REPLACE
FUNCTION drop_resource_indexes(_resource text)
RETURNS bigint
LANGUAGE sql AS $$
  SELECT count(_eval(drop_index_search_param_exp(ROW(x.*))))
  from fhir.resource_indexables x
  where resource_type = _resource
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION drop_all_resource_indexes()
RETURNS bigint
LANGUAGE sql AS $$
  SELECT count(_eval(drop_index_search_param_exp(ROW(x.*))))
  from fhir.resource_indexables x
$$ IMMUTABLE;


SELECT drop_all_resource_indexes();
SELECT index_all_resources();
--}}}
