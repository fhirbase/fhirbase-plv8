--db:fhirb -e
SET escape_string_warning=off;
--{{{
\set org1 `cat test/fixtures/org1.json`
\set org_uuid '550e8400-e29b-41d4-a716-446655440009'
\set org_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'
\set pt_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt_noise `cat test/fixtures/pt_noise.json`
\set pt_noise_uuid '550e8400-e29b-41d4-a716-446655440011'
\set pt_noise_tags  '[{"scheme": "http://pt.com", "term": "http://pt/noise", "label":"noise"}]'

BEGIN;

SELECT insert_resource(:'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);
SELECT insert_resource(:'pt_noise_uuid'::uuid, :'pt_noise'::jsonb, :'pt_noise_tags'::jsonb);

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by name')
  FROM search('Patient', '{"name": "roel"}');

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by identifier')
  FROM search('Patient', '{"identifier": "123456789"}');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"identifier": "MRN|7777777"}'))
 ,'pt found by mrn');

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by status')
  FROM search('Patient', '{"active": "true"}');

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by status')
  FROM search('Patient', '{"active": "true"}');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"telecom": "+31612345678"}'))
 ,'pt found by phone');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"gender": "http://snomed.info/sct|248153007"}'))
 ,'pt found by snomed gender');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"birthdate": "1960"}'))
 ,'pt found birthdate');

SELECT assert_eq(:'org_uuid',
 (SELECT logical_id
    FROM search('Organization', '{"name": "Health Level"}'))
 ,'org by name');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"provider.name": "Health Level"}'))
 ,'pt by org name');


SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"name": "Roelof",  "provider.name": "Health Level"}'))
 ,'pt by name & org name');

SELECT assert_eq('http://pt/vip',
 (SELECT string_agg(jsonb_array_elements#>>'{category,0,term}','')
    FROM jsonb_array_elements(
            search_bundle('Patient', '{"_tag": "http://pt/vip"}')->'entry'))
 ,'pt by tag');

ROLLBACK;
--}}}
