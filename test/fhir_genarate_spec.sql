-- #import ../src/tests.sql
-- #import ../src/fhir/generate.sql

BEGIN;

drop table if exists patient;
drop table if exists patient_history;

SELECT generate.generate_tables('{Patient}');
/* generate.generate_tables(null) => '99' */

SELECT count(*) from patient => 0::bigint

ROLLBACK;

