--db:fhirb
--{{{
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

BEGIN;

INSERT into organization (logical_id,content) values (:'org_uuid', :'org1'::jsonb);
INSERT into patient (logical_id,content) values (:'pt_uuid',  format(:'pt', :'org_uuid')::jsonb);
INSERT into patient (logical_id,content) values (:'pt2_uuid', :'pt2'::jsonb);

SELECT * FROM _parse_param('provider=Seven');
SELECT * FROM _expand_search_params('Patient','provider.name=Seven');
SELECT * FROM build_search_query('Patient','provider.name=Seven');

SELECT assert_eq(
(SELECT logical_id FROM search('Patient','provider.name=Seven') LIMIT 1),
:'pt_uuid'::uuid,
'chained search');

ROLLBACK;
--}}}
