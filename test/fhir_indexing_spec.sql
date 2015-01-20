-- #import ../src/tests.sql
-- #import ../src/fhir/generate.sql
-- #import ../src/fhir/indexing.sql

BEGIN;
  SET search_path TO indexing, vars, public;

  /* SELECT drop_all_resource_indexes(); */
  SELECT drop_index_search_param('Patient','name');
  SELECT generate.generate_tables('{Patient}'::text[]);
  SELECT index_search_param('Patient','name');
  SELECT drop_index_search_param('Patient','name');
  /* SELECT index_all_resources(); */

ROLLBACK;
