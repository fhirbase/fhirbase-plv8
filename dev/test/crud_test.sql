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
  'vid',
  _extract_vid('rid/_history/vid'),
  '_extract_vid'
);

--}}}
--{{{
\set cfg '{"base":"https://test.me"}'
\set pt `cat test/fixtures/pt.json`
\set pt2 `cat test/fixtures/pt2.json`
\set pt_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

BEGIN;

WITH created AS (
  SELECT fhir_create(:'cfg'::jsonb, 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) bundle
)

SELECT assert_eq(c.bundle#>'{entry,0,content}', :'pt'::jsonb, 'fhir_create')
FROM created c;

ROLLBACK;
--}}}
