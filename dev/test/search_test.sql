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

\set cfg '{"base":"https://test.me"}'

BEGIN;

INSERT into organization (logical_id, content) values (:'org_uuid', :'org1'::jsonb);
INSERT into patient (logical_id,content) values (:'pt_uuid',  format(:'pt', :'org_uuid')::jsonb);
INSERT into patient (logical_id,content) values (:'pt2_uuid', :'pt2'::jsonb);

SELECT assert_eq(
  :'pt_uuid',
  (SELECT string_agg(logical_id::text,' ') FROM search('Patient', 'name=roel')),
  'find pt');

SELECT assert_eq(
  :'pt_uuid',
  (SELECT string_agg(logical_id::text,' ') FROM search('Patient', 'identifier=123456789')),
  'search by identifier');

SELECT assert_eq(
  :'pt_uuid',
  (SELECT string_agg(logical_id::text,' ') FROM search('Patient', 'provider=' || :'org_uuid')),
  'search by provider');

SELECT assert_eq(
  :'pt_uuid',
  (SELECT string_agg(logical_id::text,' ') FROM search('Patient', 'provider=' || :'org_uuid')),
  'search by provider');

SELECT assert_eq( NULL ,
  (SELECT string_agg(logical_id::text,' ') FROM search('Patient', 'provider=nonexist')),
  'search by nonexisting provider');

ROLLBACK;
--}}}
