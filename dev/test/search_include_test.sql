--db:fhirb -e
SET escape_string_warning=off;

--{{{
-- TESTS ON _include
-------------------------------------------------
\set org1 `cat test/fixtures/org1.json`
\set org_uuid '550e8400-e29b-41d4-a716-446655440009'
\set org_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'
\set pt_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt2 `cat test/fixtures/pt2.json`
\set pt2_uuid '550e8400-e29b-41d4-a716-446655440011'
\set pt2_tags  '[{"scheme": "http://pt.com", "term": "http://pt/noise", "label":"noise"}]'

\set doc_ref `cat test/fixtures/documentreference-example.json`
\set doc_ref_uuid '550e8400-e29b-41d4-a716-446655440012'

\set cfg '{"base":"https://test.me"}'

BEGIN;

SELECT insert_resource(:'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);
SELECT insert_resource(:'pt2_uuid'::uuid, :'pt2'::jsonb, :'pt2_tags'::jsonb);
SELECT insert_resource(:'doc_ref_uuid'::uuid, :'doc_ref'::jsonb, '[]'::jsonb);

SELECT assert_eq(:'org_uuid' || '|' || :'pt_uuid',
(
  SELECT string_agg(logical_id::varchar, '|')
    FROM search('Patient', 'name=Roel&_include=Patient.managingOrganization')
),
'search should include resources specified in _include');

SELECT assert_eq(:'pt_uuid', (SELECT string_agg(logical_id::varchar, '|')),
  'search should ignore wrong paths in _include')
  FROM search('Patient', 'name=Roel&_include=Patient.foobar');

--}}}
