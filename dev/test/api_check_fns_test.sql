--db:fhirb
SET escape_string_warning=off;
--{{{
\set cfg '{"base":"https://test.me"}'
\set pt '{"resourceType": "Patient"}'
\set pt_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

BEGIN;

WITH reading AS (
   SELECT
     _extract_id(created.created#>>'{entry,0,id}') as id,
     _extract_vid(created.created#>>'{entry,0,link,0,href}') as vid,
     fhir_read(:'cfg', 'Patient', created.created#>>'{entry}') as entry,
     fhir_read(:'cfg', 'Patient', created.created#>>'{entry,0,id}') as bundle
   FROM fhir_create(:'cfg', 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) created
),
res_exists AS (

  SELECT assert_eq(
    (SELECT fhir_is_resource_exists(:'cfg'::jsonb, 'Patient', r.id)),
    true,
    'should exists')
  FROM reading r

),
last_version AS (

  SELECT assert_eq(
    (SELECT fhir_is_latest_resource(:'cfg'::jsonb, 'Patient', r.id, r.vid)),
    true,
    'should be latest')
    FROM reading r
),
updated AS (

    SELECT fhir_update(:'cfg', 'Patient',
            (x.entry#>>'{entry,0,id}'),
            x.entry#>>'{entry,0,link,0,href}',
            :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
    FROM reading x
),
not_last_version AS (

  SELECT assert_eq(
    (SELECT fhir_is_latest_resource(:'cfg', 'Patient', r.id, r.vid)),
    false,
    'should not be latest')
    FROM reading r
),
is_not_deleted AS (
  SELECT assert_eq(
    (SELECT fhir_is_deleted_resource(:'cfg', 'Patient', r.id)),
    false,
    'should not be deleted')
    FROM reading r
),
removed AS (
  SELECT fhir_delete(:'cfg', 'Patient', r.entry#>>'{entry,0,id}')
  from reading r
),
is_deleted AS (
  SELECT assert_eq(
    (SELECT fhir_is_deleted_resource(:'cfg', 'Patient', r.id)),
    true,
    'should be deleted')
    FROM reading r
)

SELECT
EXISTS( select * from res_exists),
EXISTS( select * from last_version),
EXISTS( select * from updated),
EXISTS( select * from not_last_version),
EXISTS( select * from is_not_deleted),
EXISTS( select * from removed),
EXISTS( select * from is_deleted)
;

ROLLBACK;
--}}}
