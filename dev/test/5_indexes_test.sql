--db:fhirb -e

SET escape_string_warning=off;
--{{{
\set pt `curl http://www.hl7.org/implement/standards/fhir/patient-example.json`

SELECT unnest(index_token_resource(:'pt'::jsonb));
--}}}

