-- #import ../src/tests.sql
-- #import ../src/fhir/generate.sql

BEGIN;

/* drop table if exists patient; */
/* drop table if exists patient_history; */

SELECT generate.generate_base_tables();
SELECT generate.generate_tables('{Patient}');
/* generate.generate_tables(null) => '99' */



SELECT count(*) from patient => 0::bigint

expect 'meta information updated'
  SELECT count(*)
    from resources.resources
    WHERE installed = true
=> 1::bigint

SELECT resource_name FROM resources.resources WHERE installed = true LIMIT 1 => 'Patient'

ROLLBACK;

