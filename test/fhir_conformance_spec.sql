-- #import ../src/tests.sql
-- #import ../src/conformance.sql

BEGIN;
conformance.conformance('{"version":"0.1"}')->>'version' => '0.1'

expect 'structuredefinition & search params unless installed'
  jsonb_array_length(
    conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
  )
=> 6



UPDATE structuredefinition
   SET installed = true
 WHERE logical_id in ('Patient', 'Encounter');

expect 'no resources unless generated'
  jsonb_array_length(
    conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
  )
=> 8


expect 'patient'
  conformance.structuredefinition(null::jsonb, 'Patient')->>'id'
=> 'Patient'

ROLLBACK;
