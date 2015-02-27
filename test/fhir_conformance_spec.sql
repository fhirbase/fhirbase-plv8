-- #import ../src/tests.sql
-- #import ../src/conformance.sql

BEGIN;
conformance.conformance('{"version":"0.1"}')->>'version' => '0.1'

expect 'profile & search params unless installed'
  jsonb_array_length(
    conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
  )
=> 4



UPDATE profile
   SET installed = true
 WHERE logical_id in ('Patient', 'Encounter');

expect 'no resources unless generated'
  jsonb_array_length(
    conformance.conformance('{"version":"0.1"}')#>'{rest,0,resource}'
  )
=> 6


expect 'patient'
  conformance.profile(null::jsonb, 'Patient')->>'id'
=> 'Patient'

ROLLBACK;
