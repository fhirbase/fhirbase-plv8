-- #import ../src/tests.sql
-- #import ../src/fhir/conformance.sql

conformance.conformance('{"version":"0.1"}')->>'version' => '0.1'
conformance.profile(null::jsonb, 'Patient')#>>'{structure,0,differential,element,0,path}' => 'Patient'
