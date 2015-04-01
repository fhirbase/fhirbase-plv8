-- #import ../src/tests.sql
-- #import ../src/fhirbase_generate.sql
-- #import ../src/fhirbase_indexing.sql

BEGIN;
  /* SELECT drop_all_resource_indexes(); */
  SELECT fhirbase_generate.generate_tables('{Patient}'::text[]);

  fhirbase_indexing._is_indexed('Patient', 'name') => false
  /* SELECT fhirbase_indexing.drop_index_search_param('Patient','name'); */
  SELECT fhirbase_indexing.index_search_param('Patient','name');

  fhirbase_indexing._is_indexed('Patient', 'name') => true

  -- second call should not raise exception
  SELECT fhirbase_indexing.index_search_param('Patient','name');

  SELECT fhirbase_indexing.drop_index_search_param('Patient','name');

  SELECT fhirbase_indexing.index_all_resources();

ROLLBACK;
