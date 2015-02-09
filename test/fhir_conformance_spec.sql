-- #import ../src/tests.sql
-- #import ../src/fhir/metadata.sql
-- #import ../src/fhir/conformance.sql

conformance.conformance('{"version":"0.1"}')->>'version' => '0.1'

expect 'no resources unless generated'
  conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
=> '[]'::jsonb


BEGIN;

UPDATE metadata.profile
   SET installed = true
 WHERE id in ('Patient', 'Encounter');

expect 'no resources unless generated'
  jsonb_array_length(
    conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
  )
=> 2

ROLLBACK;

expect 'patient'
  conformance.profile(null::jsonb, 'Patient')->>'id'
=> 'Patient'
