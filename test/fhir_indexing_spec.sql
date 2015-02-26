-- #import ../src/tests.sql
-- #import ../src/generate.sql
-- #import ../src/indexing.sql

BEGIN;
  /* SELECT drop_all_resource_indexes(); */
  SELECT generate.generate_tables('{Patient}'::text[]);

  /* SELECT indexing.drop_index_search_param('Patient','name'); */
  SELECT indexing.index_search_param('Patient','name');
  SELECT indexing.drop_index_search_param('Patient','name');
  /* SELECT index_all_resources(); */

ROLLBACK;
