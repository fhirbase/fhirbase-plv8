-- #import ../src/tests.sql
-- #import ../src/fhir/conformance.sql

conformance.conformance('{"version":"0.1"}')->>'version' => '0.1'

expect 'no resources unless generated'
  conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
=> '[]'::jsonb


BEGIN;

UPDATE resources.resources
   SET installed = true
 WHERE resource_name in ('Patient', 'Encounter');

expect 'no resources unless generated'
  jsonb_array_length(
    conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
  )
=> 2

ROLLBACK;

conformance.profile(null::jsonb, 'Patient')#>>'{structure,0,differential,element,0,path}' => 'Patient'
