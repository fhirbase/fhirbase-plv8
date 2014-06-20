--db:fhirb -e
--{{{

SELECT table_name FROM information_schema.tables
 WHERE table_schema='public'
   AND table_name = 'allergyintolerance_tag';

--}}}

--{{{
\set obs `curl http://www.hl7.org/implement/standards/fhir/observation-example-f001-glucose.json`
\set pt `curl http://www.hl7.org/implement/standards/fhir/patient-example-b.json`
\set uuid '550e8400-e29b-41d4-a716-446655440000'
\set obs_tags '[{"scheme": "obs.com", "term": "obs"}]'
\set pt_tags  '[{"scheme": "pt.com", "term": "pt"}]'

BEGIN;

SELECT insert_resource(:'uuid'::uuid, :'obs'::jsonb, :'obs_tags'::jsonb);
SELECT insert_resource(:'uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);

SELECT tags();
SELECT tags('Observation');
SELECT tags('Patient');
SELECT tags('Observation', :'uuid');
SELECT tags('Patient', :'uuid');

SELECT remove_tags('Patient', :'uuid');
SELECT assert(
         tags('Patient', :'uuid') = '{"category": [], "resourceType": "TagList"}',
              'should be empty');

ROLLBACK;
--}}}
