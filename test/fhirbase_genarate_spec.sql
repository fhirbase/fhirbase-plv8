-- #import ../src/tests.sql
-- #import ../src/fhirbase_generate.sql

BEGIN;

SELECT fhirbase_generate.generate_tables('{Patient}');

SELECT count(*) from patient => 0::bigint

expect 'meta information updated'
  SELECT count(*)
    from structuredefinition
    WHERE installed = true
=> 7::bigint

SELECT installed FROM structuredefinition WHERE logical_id = 'Patient' LIMIT 1 => true

SELECT fhirbase_generate.drop_tables('{Patient}');

SELECT installed FROM structuredefinition WHERE logical_id = 'Patient' LIMIT 1 => false

SELECT fhirbase_generate.generate_tables();

ROLLBACK;

