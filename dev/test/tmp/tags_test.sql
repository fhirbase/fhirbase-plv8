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
\set cfg '{"base":"https://test.me"}'

BEGIN;

SELECT insert_resource(:'obs_uuid'::uuid, :'obs'::jsonb, :'obs_tags'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);

SELECT fhir_tags(:'cfg');
SELECT fhir_tags(:'cfg','Observation');
SELECT fhir_tags(:'cfg','Observation', :'obs_uuid');

SELECT fhir_tags(:'cfg','Patient');
SELECT fhir_tags(:'cfg','Patient', :'pt_uuid');

SELECT fhir_remove_tags(:'cfg','Patient', :'pt_uuid');

SELECT assert_eq(
  '{"category": null, "resourceType": "TagList"}',
  fhir_tags(:'cfg','Patient', :'pt_uuid'),
'should be empty');

SELECT fhir_affix_tags(:'cfg','Patient', :'pt_uuid', :'pt_tags');

SELECT assert(category IS NOT NULL, 'populate category column')
FROM patient WHERE logical_id = :'pt_uuid';

SELECT assert_eq(
  (SELECT fhir_affix_tags(:'cfg','Patient', :'pt_uuid', :'pt_tags')),
  '[]'::jsonb,
'should not insert twice');

SELECT assert_eq(
  (SELECT fhir_tags(:'cfg','Patient', :'pt_uuid')),
  '{"category": [{"scheme":"pt.com", "term":"pt", "label":"pt"}], "resourceType": "TagList"}',
'should populate again');

SELECT 'ok'
FROM update_resource(:'pt_uuid', :'pt', '[{"term":"second", "label":"second", "scheme": "pt.second.com"}]');

WITH
version AS (
  SELECT resource_version_id AS  vid
    FROM patient_tag_history
    WHERE resource_id = :'pt_uuid'
), tgs AS (
  SELECT fhir_tags(:'cfg','Patient', :'pt_uuid', (SELECT vid FROM version LIMIT 1)) t
)
SELECT assert_eq(
  '{"category": [{"term": "pt", "label": "pt", "scheme": "pt.com"}], "resourceType": "TagList"}',
  (SELECT t from tgs limit 1),
'should show history tags');


SELECT assert_eq(
  $JSON$
  {
   "category": [
      {"term": "pt", "label": "pt", "scheme": "pt.com"},
      {"term": "second", "label": "second", "scheme": "pt.second.com"}
    ],
   "resourceType": "TagList"
  }
  $JSON$,
  (SELECT fhir_tags(:'cfg','Patient', :'pt_uuid')),
'should attach old tags to new version with new tags');

SELECT fhir_remove_tags(:'cfg','Patient', :'pt_uuid',
            (SELECT resource_version_id
              FROM patient_tag_history
              WHERE resource_id = :'pt_uuid' limit 1));

SELECT assert_eq(
  NULL,
  (SELECT category FROM patient_history WHERE logical_id = :'pt_uuid'),
'clear hx category column');

WITH tgs AS (
  SELECT fhir_tags(:'cfg','Patient',
            :'pt_uuid',
            (SELECT resource_version_id
              FROM patient_tag_history
              WHERE resource_id = :'pt_uuid' limit 1)) as t
)
SELECT assert_eq(
  '{"category": null, "resourceType": "TagList"}',
  (SELECT t from tgs limit 1),
'should show history tags');


-- affix twice some tags to version without tags
SELECT fhir_affix_tags(:'cfg','Patient', :'pt_uuid',
                   (SELECT version_id FROM patient_history WHERE logical_id = :'pt_uuid' limit 1),
                   '[{"term": "pt1", "label": "pt", "scheme": "pt.com"}]'::jsonb);

SELECT fhir_affix_tags(:'cfg','Patient', :'pt_uuid',
                   (SELECT version_id FROM patient_history WHERE logical_id = :'pt_uuid' limit 1),
                   '[{"term": "pt2", "label": "pt", "scheme": "pt.com"}]'::jsonb);



SELECT assert_eq(
  $JSON$
   [{"term": "pt1", "label": "pt", "scheme": "pt.com"},
    {"term": "pt2", "label": "pt", "scheme": "pt.com"}]
  $JSON$,
  (SELECT category FROM patient_history WHERE logical_id = :'pt_uuid'),
'populate version category column with affixed tags');

SELECT fhir_tags(:'cfg','Patient');
SELECT fhir_tags(:'cfg','Patient', :'pt_uuid');

SELECT assert_eq(
  '{"category": [{"term": "pt1", "label": "pt", "scheme": "pt.com"}, {"term": "pt2", "label": "pt", "scheme": "pt.com"}], "resourceType": "TagList"}',
  (SELECT fhir_tags(:'cfg','Patient',
            :'pt_uuid',
            (SELECT resource_version_id
              FROM patient_tag_history
              WHERE resource_id = :'pt_uuid' limit 1))),
'test version tags');

ROLLBACK;
--}}}
