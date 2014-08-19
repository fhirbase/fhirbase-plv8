--db:fhirb -e
SET escape_string_warning=off;
SET escape_string_warning=off;

--{{{
BEGIN;

SELECT assert_eq('version', (SELECT fhir_conformance('{"version":"version"}'))->>'version', 'version');

SELECT assert_eq('Patient',
   (fhir_profile(null::jsonb, 'Patient')#>>'{structure,0,element,0,path}'),
  'conformance');
ROLLBACK;

--}}}
