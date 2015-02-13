-- #import ../src/tests.sql
-- #import ../src/fhir/generate.sql
-- #import ../src/fhir/valuesets.sql

BEGIN;

SELECT generate.generate_tables('{Patient}');

SELECT count(*) from patient => 0::bigint

expect 'meta information updated'
  SELECT count(*)
    from profile
    WHERE installed = true
=> 5::bigint

SELECT installed FROM profile WHERE logical_id = 'Patient' LIMIT 1 => true

ROLLBACK;

