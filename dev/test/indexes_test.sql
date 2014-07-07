--db:fhirb -e

SET escape_string_warning=off;
--{{{
\set pt `cat test/fixtures/pt.json`
SELECT unnest(index_token_resource(:'pt'::jsonb));
--}}}
