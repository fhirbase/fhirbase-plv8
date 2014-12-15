--db:fhirb
--{{{
SELECT assert_eq(
  'base/a/b/c',
  _build_url('{"base":"base"}', 'a','b','c'),
  '_build_url'
);
SELECT assert_eq(
  'base/a/1/c',
  _build_url('{"base":"base"}', 'a',1::text,'c'),
  '_build_url'
);

SELECT assert_eq(
  '{"rel": "self", "href": "base/Patient/a9c6bcbe-3319-47dc-8e68-6cd318f79b94/_history/fba704fc-32f9-4f57-ae92-4c767c672b07"}'::jsonb,
  _build_link('{"base":"base"}', 'Patient','a9c6bcbe-3319-47dc-8e68-6cd318f79b94','fba704fc-32f9-4f57-ae92-4c767c672b07'),
  '_build_link'
);

SELECT assert_eq(
  'base/Patient/a9c6bcbe-3319-47dc-8e68-6cd318f79b94'::text,
  _build_id('{"base":"base"}', 'Patient','a9c6bcbe-3319-47dc-8e68-6cd318f79b94'),
  '_build_id'
);

SELECT assert_eq(
  'rid',
  _extract_id('rid/_history/vid'),
  '_extract_id'
);

SELECT assert_eq(
  'rid',
  _extract_id('http://ups/rid/_history/vid'),
  '_extract_id'
);

SELECT assert_eq(
  'vid',
  _extract_vid('rid/_history/vid'),
  '_extract_vid'
);
SELECT assert_eq(
  'vid',
  _extract_vid('http://ups/rid/_history/vid'),
  '_extract_vid'
);

\set cfg '{"base":"https://test.me"}'
\set pt `cat test/fixtures/pt.json`
\set pt_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

BEGIN;

WITH created AS (
  SELECT fhir_create(:'cfg'::jsonb, 'Patient'::text, :'pt'::jsonb, :'pt_tags'::jsonb) bundle
), vreaded AS (
  SELECT fhir_vread(:'cfg'::jsonb, 'Patient'::text, bundle#>>'{entry,0,link,0,href}') as bundle
    FROM created
)
SELECT assert_eq(c.bundle#>'{entry,0,content}', :'pt'::jsonb, 'fhir_create')
FROM created c
UNION
SELECT assert_eq(c.bundle#>'{entry,0,content}', :'pt'::jsonb, 'fhir_vread')
FROM vreaded c
;

ROLLBACK;

\set cfg '{"base":"https://test.me"}'
\set pt `cat test/fixtures/pt.json`
\set upt '{"resourceType":"Patient"}'
\set pt_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

BEGIN;

WITH created AS (
  SELECT fhir_create(:'cfg'::jsonb, 'Patient'::text, :'pt'::jsonb, :'pt_tags'::jsonb) bundle
), updated AS (
  SELECT fhir_update(:'cfg'::jsonb, 'Patient'::text,bundle#>>'{entry,0,id}', bundle#>>'{entry,0,link,0,href}', :'upt'::jsonb, '[]'::jsonb) as bundle
  FROM created
)
SELECT assert_eq(
  (SELECT c.bundle#>'{entry,0,content}' FROM updated c),
  :'upt'::jsonb,
  'fhir_update');


SELECT assert_eq(1::bigint,
  (SELECT count(*) from patient),
  'count');

SELECT assert_eq(1::bigint,
  (SELECT count(*) from patient_history),
  'history count');

SELECT assert_eq(2,
(SELECT  jsonb_array_length(x#>'{entry}')
 FROM
 fhir_history(:'cfg'::jsonb,
  'Patient',
  (SELECT logical_id from patient_history limit 1)::text, null) x),
'fhir_history');

SELECT assert_eq(2,
(SELECT jsonb_array_length(x->'entry') FROM  fhir_history(:'cfg'::jsonb, 'Patient',null) x)
,'fhir_history resource');

SELECT assert_eq(2,
(SELECT jsonb_array_length(x->'entry') FROM  fhir_history(:'cfg'::jsonb, null) x)
,'fhir_history all resources');

SELECT assert_eq(true,
  (SELECT fhir_is_latest_resource(:'cfg'::jsonb, 'Patient', logical_id::text, version_id::text)
    FROM patient LIMIT 1
  ),
  'fhir_is_latest_resource');

SELECT assert_eq(false,
  (SELECT fhir_is_latest_resource(:'cfg'::jsonb, 'Patient', logical_id::text, version_id::text)
    FROM patient_history LIMIT 1
  ),
  'fhir_is_latest_resource');

SELECT assert_eq(false,
  (SELECT fhir_is_deleted_resource(:'cfg'::jsonb, 'Patient', (select logical_id::text from patient_history limit 1))),
  'fhir_is_deleted_resource');

ROLLBACK;

\set cfg '{"base":"https://test.me"}'
\set pt `cat test/fixtures/pt.json`
\set pt_tags '[]'

BEGIN;

WITH created AS (
  SELECT fhir_create(:'cfg'::jsonb, 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) bundle
), deleted AS (
  SELECT fhir_delete(:'cfg'::jsonb, 'Patient'::text,bundle#>>'{entry,0,id}') bundle
  FROM created
)
SELECT assert_eq(
  (SELECT c.bundle#>'{entry,0,content}' FROM deleted c),
  :'pt'::jsonb,
  'fhir_delete');

SELECT assert_eq(0::bigint,
  (SELECT count(*) from patient),
  'count');

SELECT assert_eq(1::bigint,
  (SELECT count(*) from patient_history),
  'history count');

SELECT assert_eq(1,
(SELECT  jsonb_array_length(x#>'{entry}')
 FROM
 fhir_history(:'cfg'::jsonb,
  'Patient',
  (SELECT logical_id from patient_history limit 1)::text, null) x),
'fhir_history');

SELECT assert_eq(true,
  (SELECT fhir_is_deleted_resource(:'cfg'::jsonb, 'Patient', (select logical_id::text from patient_history limit 1))),
  'fhir_is_deleted_resource');

ROLLBACK;
--}}}
