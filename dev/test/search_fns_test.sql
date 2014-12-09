--db:fhirb
--{{{

\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'

BEGIN;

SELECT build_sorting('Patient', '_sort=given');

ROLLBACK;
--}}}
