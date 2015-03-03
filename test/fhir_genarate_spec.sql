-- #import ../src/tests.sql
-- #import ../src/generate.sql

BEGIN;

SELECT generate.generate_tables('{Patient}');

SELECT count(*) from patient => 0::bigint

expect 'meta information updated'
  SELECT count(*)
    from structuredefinition
    WHERE installed = true
=> 7::bigint

SELECT installed FROM structuredefinition WHERE logical_id = 'Patient' LIMIT 1 => true

SELECT generate.generate_tables();

ROLLBACK;

