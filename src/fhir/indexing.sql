-- #import ../coll.sql
-- #import ../gen.sql
-- #import ./metadata.sql
-- #import ./index_fns.sql
-- #import ./index_date.sql

CREATE EXTENSION IF NOT EXISTS btree_gist ;

func _token_index_fn(dtype varchar, is_primitive boolean) RETURNS text
  SELECT  'index_fns.index_' || CASE WHEN is_primitive THEN 'primitive' ELSE lower(dtype::varchar) END || '_as_token'

func _index_name(_meta resources.resource_indexables) RETURNS text
  SELECT replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' ||  coll._last(_meta.path) || '_' || _meta.search_type || '_idx')::varchar,'-','_')

func index_token_exp(_meta resources.resource_indexables) RETURNS text
  SELECT
   format(
    'CREATE INDEX %I ON %I USING GIN (%s(content,%L))'
    , this._index_name(_meta)
    , lower(_meta.resource_type)
    , this._token_index_fn(_meta.type, _meta.is_primitive)
    , coll._rest(_meta.path)::varchar
   )

func index_reference_exp(_meta resources.resource_indexables) RETURNS text
  SELECT
    format(
      'CREATE INDEX %I ON %I USING GIN (index_fns.index_as_reference(content,%L))'
      ,this._index_name(_meta)
      ,lower(_meta.resource_type)
      ,coll._rest(_meta.path)::varchar
    )

func index_string_exp(_meta resources.resource_indexables) RETURNS text
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIN (index_fns.index_as_string(content,%L::text[]) gin_trgm_ops)'
      ,this._index_name(_meta)
      ,lower(_meta.resource_type)
      ,coll._rest(_meta.path)::varchar
    )

func index_date_exp(_meta resources.resource_indexables) RETURNS text
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIST (index_date.index_as_date(content,%L::text[], %L) range_ops)'
      ,this._index_name(_meta)
      ,lower(_meta.resource_type)
      ,coll._rest(_meta.path)::varchar
      ,_meta.type
    )

func index_search_param_exp(x resources.resource_indexables) RETURNS text
 SELECT
 CASE
   WHEN x.search_type = 'token' THEN this.index_token_exp(x)
   WHEN x.search_type = 'reference' THEN this.index_reference_exp(x)
   WHEN x.search_type = 'string' THEN this.index_string_exp(x)
   WHEN x.search_type = 'date' THEN this.index_date_exp(x)
   ELSE ''
 END

func index_search_param(_resource_type text, _param_name text) RETURNS text
  SELECT count(gen._eval(this.index_search_param_exp(ROW(x.*))))::text
  FROM resources.resource_indexables x
  WHERE resource_type = _resource_type
  AND  param_name = _param_name

func drop_index_search_param_exp(_meta resources.resource_indexables) RETURNS text
  SELECT format('DROP INDEX IF EXISTS %I',this._index_name(_meta))

-- TODO: implement for symmetric api
func drop_index_search_param(_resource_type text, _param_name text) RETURNS bigint
  SELECT count(gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  FROM resources.resource_indexables x
  WHERE resource_type = _resource_type
  AND  param_name = _param_name

-- index token
func index_resource(_resource text) RETURNS table (idx text)
  SELECT
  gen._eval(this.index_search_param_exp(ROW(x.*)))
  from resources.resource_indexables x
  where search_type IN ('token', 'reference', 'string', 'date')
  and resource_type = _resource

func index_all_resources() RETURNS table (idx text)
  SELECT
  gen._eval(this.index_search_param_exp(ROW(x.*)))
  from resources.resource_indexables x
  where search_type IN ('token', 'reference', 'string', 'date')

func drop_resource_indexes(_resource text) RETURNS bigint
  SELECT count(gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  from resources.resource_indexables x
  where resource_type = _resource

func drop_all_resource_indexes() RETURNS bigint
  SELECT count(gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  from resources.resource_indexables x
