--db:fhirb -e
SET escape_string_warning=off;
SET escape_string_warning=off;

--{{{
BEGIN;
  SELECT assert_eq('version', (SELECT fhir_conformance('{"version":"version"}'))->>'version', 'version');
ROLLBACK;
--}}}
