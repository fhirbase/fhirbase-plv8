--db:fhirb
SET escape_string_warning=off;
--{{{


\set old_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'
\set new_tags '[{"scheme": "http://pt2.com", "term": "http://pt/vip2", "label":"pt2"}]'
\set more_tags '[{"scheme": "http://pt3.com", "term": "http://pt/vip3", "label":"pt3"}]'


BEGIN;

SELECT 'insert' FROM fhir_create('{}'::jsonb, 'Patient', '{"resourceType":"Patient"}'::jsonb, :'old_tags'::jsonb);

SELECT assert_eq(
  :'old_tags'::jsonb,
  (
    SELECT x->'category'
    FROM fhir_tags('{}'::jsonb, 'Patient', (SELECT logical_id from patient)) x
),'fhir_tags');

SELECT fhir_affix_tags('{}'::jsonb,
  'Patient',
  (SELECT logical_id from patient),
  :'new_tags'::jsonb
);

SELECT assert_eq(
  _merge_tags(:'new_tags'::jsonb, :'old_tags'),
  (
    SELECT x->'category'
    FROM fhir_tags('{}'::jsonb, 'Patient', (SELECT logical_id from patient)) x
),'fhir_tags');

SELECT 'update' FROM (
  SELECT fhir_update('{}'::jsonb,
    'Patient'::text,
    logical_id::text,
    version_id::text,
    '{"resourceType":"Patient"}'::jsonb,
    :'new_tags'::jsonb)
  FROM patient
) _ ;


SELECT fhir_tags('{}'::jsonb, 'Patient'::text, logical_id, version_id)
FROM patient_history
LIMIT 1;


SELECT fhir_affix_tags('{}'::jsonb, 'Patient'::text, logical_id, version_id, :'more_tags'::jsonb)
FROM patient_history
LIMIT 1;

SELECT fhir_tags('{}'::jsonb, 'Patient'::text, logical_id, version_id)
FROM patient_history
LIMIT 1;

SELECT fhir_remove_tags('{}'::jsonb, 'Patient'::text, logical_id)
FROM patient
LIMIT 1;

SELECT fhir_tags('{}'::jsonb, 'Patient'::text, logical_id)
FROM patient
LIMIT 1;

SELECT fhir_remove_tags('{}'::jsonb, 'Patient'::text, logical_id, version_id)
FROM patient_history
LIMIT 1;

SELECT fhir_tags('{}'::jsonb, 'Patient'::text, logical_id, version_id)
FROM patient_history
LIMIT 1;

ROLLBACK;

--}}}
