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
\set pt_tags  '[{"scheme": "pt.com", "term": "pt", "label":"pt"}]'

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

SELECT affix_tags('Patient', :'uuid', :'pt_tags');

SELECT assert(affix_tags('Patient', :'uuid', :'pt_tags') = '[]'::jsonb, 'should not insert twice');

SELECT assert(
         tags('Patient', :'uuid') = '{"category": [{"scheme":"pt.com", "term":"pt", "label":"pt"}], "resourceType": "TagList"}',
              'should populate again');

SELECT 'ok' FROM update_resource(:'uuid', :'pt', '[]');

WITH tgs AS (
  SELECT tags('Patient',
            :'uuid',
            (SELECT resource_version_id
              FROM patient_history_tag
              WHERE resource_id = :'uuid' limit 1)) as t
)
SELECT assert((SELECT t from tgs limit 1)
           = '{"category": [{"term": "pt", "label": "pt", "scheme": "pt.com"}], "resourceType": "TagList"}'
        , 'should show history tags');

SELECT remove_tags('Patient', :'uuid',
            (SELECT resource_version_id
              FROM patient_history_tag
              WHERE resource_id = :'uuid' limit 1));

WITH tgs AS (
  SELECT tags('Patient',
            :'uuid',
            (SELECT resource_version_id
              FROM patient_history_tag
              WHERE resource_id = :'uuid' limit 1)) as t
)
SELECT assert((SELECT t from tgs limit 1)
           = '{"category": [], "resourceType": "TagList"}'
        , 'should show history tags');

SELECT affix_tags('Patient', :'uuid',
                   (SELECT version_id FROM patient_history WHERE logical_id = :'uuid' limit 1),
                  :'pt_tags'::jsonb);

SELECT affix_tags('Patient', :'uuid',
                   (SELECT version_id FROM patient_history WHERE logical_id = :'uuid' limit 1),
                  :'obs_tags'::jsonb);

SELECT tags('Patient');
SELECT tags('Patient', :'uuid');

SELECT tags('Patient',
          :'uuid',
          (SELECT resource_version_id
            FROM patient_history_tag
            WHERE resource_id = :'uuid' limit 1));

ROLLBACK;
--}}}
