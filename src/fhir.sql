-- #import ./generate.sql
-- #import ./conformance.sql
-- #import ./crud.sql
-- #import ./indexing.sql
-- #import ./search.sql

-- AIP facade

-- generation

func! generate_tables(_profiles_ text[]) returns text
  select generate.generate_tables(_profiles_)

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
func conformance(_cfg jsonb) RETURNS jsonb
   SELECT conformance.conformance(_cfg )

func profile(_cfg jsonb, _resource_name_ text) RETURNS jsonb
  SELECT conformance.profile(_cfg , _resource_name_)

-- crud

func! read(_cfg_ jsonb, _id_ text) RETURNS jsonb
  SELECT crud.read(_cfg_ , _id_ )

func! vread(_cfg_ jsonb, _id_ text) RETURNS jsonb
  SELECT crud.vread(_cfg_ , _id_ )

func! create(_cfg_ jsonb, _resource_ jsonb) RETURNS jsonb
  SELECT crud.create(_cfg_, _resource_)

func! update(_cfg_ jsonb, _resource_ jsonb) RETURNS jsonb
  SELECT crud.update(_cfg_ , _resource_ )

func! delete(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS jsonb
  SELECT crud.delete(_cfg_ , _resource_type_ , _id_)

func! is_deleted(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS boolean
  SELECT crud.is_deleted(_cfg_ , _resource_type_ , _id_ )

func! is_latest(_cfg_ jsonb, _resource_type_ text, _id_ text, _vid_ text) RETURNS boolean
  SELECT crud.is_latest(_cfg_ , _resource_type_ , _id_ , _vid_ )

func! is_exists(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS boolean
  SELECT crud.is_exists(_cfg_ , _resource_type_ , _id_ )

func! history(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS jsonb
  SELECT crud.history(_cfg_ , _resource_type_ , _id_ )

func! history(_cfg_ jsonb, _resource_type_ text) RETURNS jsonb
  SELECT crud.history(_cfg_ , _resource_type_ )

func! history(_cfg_ jsonb) RETURNS jsonb
  SELECT crud.history(_cfg_)

-- search

func search(_cfg_ jsonb, _type_ text, _params_ text) RETURNS jsonb
  SELECT search.fhir_search(_cfg_ , _type_ , _params_ )

func! explain_search(_resource_type text, query text) RETURNS table( "plan" text)
  SELECT search.explain_search(_resource_type, query)

func! _search(_resource_type text, query text) RETURNS SETOF resource
  SELECT search.search(_resource_type, query)

func! search_sql(_resource_type_ text, _query_ text) RETURNS table( "plan" text)
  SELECT search.build_search_query(_resource_type_, _query_)
