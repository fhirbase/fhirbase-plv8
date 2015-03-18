-- #import ./generate.sql
-- #import ./conformance.sql
-- #import ./crud.sql
-- #import ./transaction.sql
-- #import ./indexing.sql
-- #import ./search.sql
-- #import ./admin.sql

-- AIP facade

-- generation

func! generate_tables(_resources_ text[]) returns text
  select generate.generate_tables(_resources_)

func! generate_tables() returns text
   SELECT generate.generate_tables()


--- indexing
func! index_search_param(_resource_type text, _name_ text) RETURNS text
  SELECT  indexing.index_search_param(_resource_type , _name_ )

func! drop_index_search_param(_resource_type text, _name_ text) RETURNS bigint
 SELECT  indexing.drop_index_search_param(_resource_type , _name_ )

func! index_resource(_resource text) RETURNS table (idx text)
 SELECT  indexing.index_resource(_resource)

func! drop_resource_indexes(_resource text) RETURNS bigint
 SELECT  indexing.drop_resource_indexes(_resource)

func! index_all_resources() RETURNS table (idx text)
 SELECT  indexing.index_all_resources()

func! drop_all_resource_indexes() RETURNS bigint
 SELECT  indexing.drop_all_resource_indexes()

-- conformance
func conformance(_cfg_ jsonb) RETURNS jsonb
   SELECT conformance.conformance(_cfg_ )

func structuredefinition(_cfg_ jsonb, _resource_name_ text) RETURNS jsonb
  SELECT conformance.structuredefinition(_cfg_ , _resource_name_)

-- crud

func! read(_resource_type_ text, _id_ text) RETURNS jsonb
  SELECT crud.read('{}'::jsonb , _id_ )

func! vread(_resource_type_ text, _id_ text) RETURNS jsonb
  SELECT crud.vread('{}'::jsonb , _id_ )

func! create(_resource_ jsonb) RETURNS jsonb
  SELECT crud.create('{}'::jsonb, _resource_)

func! update(_resource_ jsonb) RETURNS jsonb
  SELECT crud.update('{}'::jsonb , _resource_ )

func! delete(_resource_type_ text, _id_ text) RETURNS jsonb
  SELECT crud.delete('{}'::jsonb , _resource_type_ , _id_)

func! is_deleted(_resource_type_ text, _id_ text) RETURNS boolean
  SELECT crud.is_deleted('{}'::jsonb , _resource_type_ , _id_ )

func! is_latest( _resource_type_ text, _id_ text, _vid_ text) RETURNS boolean
  SELECT crud.is_latest('{}'::jsonb , _resource_type_ , _id_ , _vid_ )

func! is_exists(_resource_type_ text, _id_ text) RETURNS boolean
  SELECT crud.is_exists('{}'::jsonb , _resource_type_ , _id_ )

func! history(_resource_type_ text, _id_ text) RETURNS jsonb
  SELECT crud.history('{}'::jsonb , _resource_type_ , _id_ )

func! history(_resource_type_ text) RETURNS jsonb
  SELECT crud.history('{}'::jsonb , _resource_type_ )

func! history() RETURNS jsonb
  SELECT crud.history('{}'::jsonb)

-- transaction

func! transaction( _bundle_ jsonb) RETURNS jsonb
  SELECT transaction.transaction('{}'::jsonb, _bundle_)

-- search

func search( _type_ text, _params_ text) RETURNS jsonb
  SELECT search.fhir_search('{}'::jsonb , _type_ , _params_ )

func! explain_search(_resource_type text, query text) RETURNS table( "plan" text)
  SELECT search.explain_search(_resource_type, query)

func! _search(_resource_type text, query text) RETURNS SETOF resource
  SELECT search.search(_resource_type, query)

func! search_sql(_resource_type_ text, _query_ text) RETURNS table( "plan" text)
  SELECT search.build_search_query(_resource_type_, _query_)

-- admin functions
func! admin_disk_usage_top(_limit_ integer) RETURNS  jsonb
  SELECT json_agg(x.*)::jsonb FROM admin.admin_disk_usage_top(_limit_) x

