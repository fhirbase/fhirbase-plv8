-- #import ./coll.sql
-- #import ./gen.sql
-- #import ./index_fns.sql
-- #import ./index_date.sql

CREATE EXTENSION IF NOT EXISTS btree_gist ;

func _token_index_fn(dtype text, is_primitive boolean) RETURNS text
  SELECT  'index_fns.index_'
  || CASE WHEN is_primitive THEN 'primitive'
          WHEN dtype IS NOT NULL THEN lower(dtype::text)
          ELSE 'ups' END
  || '_as_token'

func _index_name(_meta searchparameter) RETURNS text
  SELECT replace(lower(_meta.base || '_' || _meta.name || '_' ||  coll._last(_meta.path) || '_' || _meta.search_type || '_idx')::text,'-','_')

func index_token_exp(_meta searchparameter) RETURNS text
  SELECT
   format(
    'CREATE INDEX %I ON %I USING GIN (%s(content,%L))'
    , this._index_name(_meta)
    , lower(_meta.base)
    , this._token_index_fn(_meta.type, _meta.is_primitive)
    , coll._rest(_meta.path)::text
   )

func index_reference_exp(_meta searchparameter) RETURNS text
  SELECT
    format(
      'CREATE INDEX %I ON %I USING GIN (index_fns.index_as_reference(content,%L))'
      ,this._index_name(_meta)
      ,lower(_meta.base)
      ,coll._rest(_meta.path)::text
    )

func index_string_exp(_meta searchparameter) RETURNS text
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIN (index_fns.index_as_string(content,%L::text[]) gin_trgm_ops)'
      ,this._index_name(_meta)
      ,lower(_meta.base)
      ,coll._rest(_meta.path)::text
    )

func index_date_exp(_meta searchparameter) RETURNS text
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIST (index_date.index_as_date(content,%L::text[], %L) range_ops)'
      ,this._index_name(_meta)
      ,lower(_meta.base)
      ,coll._rest(_meta.path)::text
      ,_meta.type
    )

func index_search_param_exp(x searchparameter) RETURNS text
 SELECT
 CASE
   WHEN x.search_type = 'token' THEN this.index_token_exp(x)
   WHEN x.search_type = 'reference' THEN this.index_reference_exp(x)
   WHEN x.search_type = 'string' THEN this.index_string_exp(x)
   WHEN x.search_type = 'date' THEN this.index_date_exp(x)
   ELSE ''
 END

func index_search_param(_resource_type text, _name_ text) RETURNS text
  SELECT count(gen._eval(this.index_search_param_exp(ROW(x.*))))::text
  FROM searchparameter x
  WHERE base = _resource_type
  AND  name = _name_

func drop_index_search_param_exp(_meta searchparameter) RETURNS text
  SELECT format('DROP INDEX IF EXISTS %I',this._index_name(_meta))

-- TODO: implement for symmetric api
func drop_index_search_param(_resource_type text, _name_ text) RETURNS bigint
  SELECT count(gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  FROM searchparameter x
  WHERE base = _resource_type
  AND  name = _name_

-- index token
func index_resource(_resource text) RETURNS table (idx text)
  SELECT
  gen._eval(this.index_search_param_exp(ROW(x.*)))
  from searchparameter x
  where search_type IN ('token', 'reference', 'string', 'date')
  and base = _resource

func index_all_resources() RETURNS table (idx text)
  SELECT
    gen._eval(this.index_search_param_exp(ROW(x.*)))
  from searchparameter x
  join structuredefinition p ON p.name = x.base AND p.installed = true
  where search_type IN ('token', 'reference', 'string', 'date')
  and x.type is not null

-- TODO: show unsupported indexes

func drop_resource_indexes(_resource text) RETURNS bigint
  SELECT count(gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  from searchparameter x
  where base = _resource

func drop_all_resource_indexes() RETURNS bigint
  SELECT count(gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  from searchparameter x
