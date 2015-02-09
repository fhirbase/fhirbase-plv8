-- #import ../src/tests.sql
-- #import ../src/fhir/generate.sql

BEGIN;

SELECT generate.generate_tables('{Patient}');

SELECT count(*) from patient => 0::bigint

expect 'meta information updated'
  SELECT count(*)
    from profile
    WHERE installed = true
=> 1::bigint

SELECT logical_id FROM profile WHERE installed = true LIMIT 1 => 'Patient'

ROLLBACK;

