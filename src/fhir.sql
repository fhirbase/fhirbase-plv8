-- #import ./fhirbase_generate.sql
-- #import ./fhirbase_conformance.sql
-- #import ./fhirbase_crud.sql
-- #import ./fhirbase_history.sql
-- #import ./fhirbase_transaction.sql
-- #import ./fhirbase_indexing.sql
-- #import ./fhirbase_search.sql
-- #import ./fhirbase_admin.sql

-- AIP facade

-- generation

func! generate_tables(_resources_ text[]) returns text
  select fhirbase_generate.generate_tables(_resources_)

func! generate_tables() returns text
   SELECT fhirbase_generate.generate_tables()

func! drop_tables(_resources_ text[]) returns text
  select fhirbase_generate.drop_tables(_resources_)

--- indexing
func! index_search_param(_resource_type text, _name_ text) RETURNS text
  SELECT  fhirbase_indexing.index_search_param(_resource_type , _name_ )

func! drop_index_search_param(_resource_type text, _name_ text) RETURNS bigint
 SELECT  fhirbase_indexing.drop_index_search_param(_resource_type , _name_ )

func! index_resource(_resource text) RETURNS table (idx text)
 SELECT  fhirbase_indexing.index_resource(_resource)

func! drop_resource_indexes(_resource text) RETURNS bigint
 SELECT  fhirbase_indexing.drop_resource_indexes(_resource)

func! index_all_resources() RETURNS table (idx text)
 SELECT  fhirbase_indexing.index_all_resources()

func! drop_all_resource_indexes() RETURNS bigint
 SELECT  fhirbase_indexing.drop_all_resource_indexes()

-- index stats

func indexes_summary() RETURNS table (tablename text, rows_in_bytes text, num_rows real, number_of_indexes bigint, "unique" text, single_column bigint, multi_column bigint)
 SELECT  fhirbase_indexing.indexes_summary()

func indexes_usage() RETURNS table (tablename text, indexname text, num_rows real, table_size text, index_size text, "unique" text, number_of_scans bigint, tuples_read bigint, tuples_fetched bigint)
 SELECT  fhirbase_indexing.indexes_usage()

func duplicate_indexes() returns table("size" text, idx1 text,idx2 text,idx3 text,idx4  text)
 SELECT  fhirbase_indexing.duplicate_indexes()

-- conformance
func conformance(_cfg_ jsonb) RETURNS jsonb
   SELECT fhirbase_conformance.conformance(_cfg_ )

func structuredefinition(_cfg_ jsonb, _resource_name_ text) RETURNS jsonb
  SELECT fhirbase_conformance.structuredefinition(_cfg_ , _resource_name_)

-- crud

func! read(_resource_type_ text, _id_ text) RETURNS jsonb
  SELECT fhirbase_crud.read('{}'::jsonb , _id_ )

func! vread(_resource_type_ text, _id_ text) RETURNS jsonb
  SELECT fhirbase_crud.vread('{}'::jsonb , _id_ )

func! create(_resource_ jsonb) RETURNS jsonb
  SELECT fhirbase_crud.create('{}'::jsonb, _resource_)

func! update(_resource_ jsonb) RETURNS jsonb
  SELECT fhirbase_crud.update('{}'::jsonb , _resource_ )

func! delete(_resource_type_ text, _id_ text) RETURNS jsonb
  SELECT fhirbase_crud.delete('{}'::jsonb , _resource_type_ , _id_)

func! is_deleted(_resource_type_ text, _id_ text) RETURNS boolean
  SELECT fhirbase_crud.is_deleted('{}'::jsonb , _resource_type_ , _id_ )

func! is_latest( _resource_type_ text, _id_ text, _vid_ text) RETURNS boolean
  SELECT fhirbase_crud.is_latest('{}'::jsonb , _resource_type_ , _id_ , _vid_ )

func! is_exists(_resource_type_ text, _id_ text) RETURNS boolean
  SELECT fhirbase_crud.is_exists('{}'::jsonb , _resource_type_ , _id_ )

func! history(_resource_type_ text, _id_ text, _parmas_ text) RETURNS jsonb
  SELECT fhirbase_history.history('{}'::jsonb , _resource_type_ , _id_ , _parmas_)

func! history_sql(_resource_type_ text, _id_ text, _parmas_ text) RETURNS text
  SELECT fhirbase_history.history_sql('{}'::jsonb , _resource_type_ , _id_ , _parmas_)

func! history(_resource_type_ text, _parmas_ text) RETURNS jsonb
  SELECT fhirbase_history.history('{}'::jsonb , _resource_type_ , _parmas_)

func! history_sql(_resource_type_ text, _parmas_ text) RETURNS text
  SELECT fhirbase_history.history_sql('{}'::jsonb , _resource_type_ , _parmas_)

func! history(_parmas_ text) RETURNS jsonb
  SELECT fhirbase_history.history('{}'::jsonb, _parmas_)

func! history_sql(_parmas_ text) RETURNS text
  SELECT fhirbase_history.history_sql('{}'::jsonb, _parmas_)

-- transaction

func! transaction( _bundle_ jsonb) RETURNS jsonb
  SELECT fhirbase_transaction.transaction('{}'::jsonb, _bundle_)

-- search

func search( _type_ text, _params_ text) RETURNS jsonb
  SELECT fhirbase_search.fhir_search('{}'::jsonb , _type_ , _params_ )

func! explain_search(_resource_type text, query text) RETURNS table( "plan" text)
  SELECT fhirbase_search.explain_search(_resource_type, query)

func! _search(_resource_type text, query text) RETURNS SETOF resource
  SELECT fhirbase_search.search(_resource_type, query)

func! search_sql(_resource_type_ text, _query_ text) RETURNS table( "plan" text)
  SELECT fhirbase_search.build_search_query(_resource_type_, _query_)

-- admin functions
func! admin_disk_usage_top(_limit_ integer) RETURNS  jsonb
  SELECT json_agg(x.*)::jsonb FROM fhirbase_admin.admin_disk_usage_top(_limit_) x

