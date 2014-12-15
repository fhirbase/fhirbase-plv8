--db:fhirb
SET escape_string_warning=off;

--{{{
-- testing _ids

\set org1 `cat test/fixtures/org1.json`
\set org_uuid '550e8400-e29b-41d4-a716-446655440009'
\set no_uuid '550e8400-e29b-41d4-a716-446655440119'
\set org_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'
\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'
\set pt_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt2 `cat test/fixtures/pt2.json`
\set pt2_uuid '550e8400-e29b-41d4-a716-446655440011'
\set pt2_tags  '[{"scheme": "http://pt.com", "term": "http://pt/noise", "label":"noise"}]'

BEGIN;

SELECT 'CREATE' FROM fhir_create('{}'::jsonb, 'Organization', :'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT 'CREATE' FROM fhir_create('{}'::jsonb, 'Patient', :'pt_uuid'::uuid, format(:'pt', :'org_uuid')::jsonb , :'pt_tags'::jsonb);
SELECT 'CREATE' FROM fhir_create('{}'::jsonb, 'Patient', :'pt2_uuid'::uuid, :'pt2'::jsonb, :'pt2_tags'::jsonb);

SELECT assert_eq(:'pt_uuid',
(
  SELECT string_agg(logical_id::varchar, '|')
  FROM search('Patient', ('_id=' || :'pt_uuid'))
), 'search by _id');

SELECT assert_eq(:'pt_uuid',
(
  SELECT string_agg(logical_id::varchar, '|')
    FROM search('Patient', ('provider._id='|| :'org_uuid'))
), 'chained search by provider._id');

SELECT assert_eq(0::bigint,
(
  SELECT count(*)
    FROM search('Patient', ('provider._id='|| :'no_uuid'))
), 'chained search by provider._id with unexisting uuid');


ROLLBACK;
--}}}
