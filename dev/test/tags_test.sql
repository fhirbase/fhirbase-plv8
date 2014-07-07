--db:fhirb -e
--{{{

SELECT table_name FROM information_schema.tables
 WHERE table_schema='public'
   AND table_name = 'allergyintolerance_tag';

--}}}

--{{{
\set obs `cat test/fixtures/observation-example-f001-glucose.json`
\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440077'
\set obs_uuid '550e8400-e29b-41d4-a716-446655440078'
\set obs_tags '[{"scheme": "obs.com", "term": "obs", "label": "obs"}]'
\set pt_tags  '[{"scheme": "pt.com", "term": "pt", "label":"pt"}]'

BEGIN;

SELECT insert_resource(:'obs_uuid'::uuid, :'obs'::jsonb, :'obs_tags'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);

SELECT fhir_tags();
SELECT fhir_tags('Observation');
SELECT fhir_tags('Observation', :'obs_uuid');

SELECT fhir_tags('Patient');
SELECT fhir_tags('Patient', :'pt_uuid');

SELECT remove_fhir_tags('Patient', :'pt_uuid');
SELECT assert(
         fhir_tags('Patient', :'pt_uuid') = '{"category": null, "resourceType": "TagList"}',
              'should be empty');

SELECT affix_fhir_tags('Patient', :'pt_uuid', :'pt_tags');

SELECT assert(category IS NOT NULL, 'populate category column') FROM patient WHERE logical_id = :'pt_uuid';

SELECT assert_eq(affix_fhir_tags('Patient', :'pt_uuid', :'pt_tags'), '[]'::jsonb, 'should not insert twice');


SELECT assert_eq(
         fhir_tags('Patient', :'pt_uuid'),
        '{"category": [{"scheme":"pt.com", "term":"pt", "label":"pt"}], "resourceType": "TagList"}',
              'should populate again');

SELECT 'ok' FROM update_resource(:'pt_uuid', :'pt', '[]');

WITH tgs AS (
  SELECT fhir_tags('Patient',
            :'pt_uuid',
            (SELECT resource_version_id
              FROM patient_tag_history
              WHERE resource_id = :'pt_uuid' limit 1)) as t
)
SELECT assert_eq((SELECT t from tgs limit 1),
         '{"category": [{"term": "pt", "label": "pt", "scheme": "pt.com"}], "resourceType": "TagList"}'
        , 'should show history tags');

SELECT remove_fhir_tags('Patient', :'pt_uuid',
            (SELECT resource_version_id
              FROM patient_tag_history
              WHERE resource_id = :'pt_uuid' limit 1));

SELECT assert_eq(category, NULL, 'clear hx category column') FROM patient_history WHERE logical_id = :'pt_uuid';

WITH tgs AS (
  SELECT fhir_tags('Patient',
            :'pt_uuid',
            (SELECT resource_version_id
              FROM patient_tag_history
              WHERE resource_id = :'pt_uuid' limit 1)) as t
)
SELECT assert((SELECT t from tgs limit 1)
           = '{"category": null, "resourceType": "TagList"}'
        , 'should show history tags');

SELECT affix_fhir_tags('Patient', :'pt_uuid',
                   (SELECT version_id FROM patient_history WHERE logical_id = :'pt_uuid' limit 1),
                  :'pt_tags'::jsonb);

SELECT affix_fhir_tags('Patient', :'pt_uuid',
                   (SELECT version_id FROM patient_history WHERE logical_id = :'pt_uuid' limit 1),
                  :'obs_tags'::jsonb);


SELECT assert(category IS NOT NULL, 'populate hx category column') FROM patient_history WHERE logical_id = :'pt_uuid';

SELECT fhir_tags('Patient');
SELECT fhir_tags('Patient', :'pt_uuid');

SELECT fhir_tags('Patient',
          :'pt_uuid',
          (SELECT resource_version_id
            FROM patient_tag_history
            WHERE resource_id = :'pt_uuid' limit 1));

ROLLBACK;
--}}}
