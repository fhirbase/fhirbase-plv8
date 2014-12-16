--db:fhirb
SET escape_string_warning=off;

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

SELECT 'created' FROM fhir_create('{}'::jsonb, 'Organization', :'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT 'created' FROM fhir_create('{}'::jsonb, 'Patient',:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);
SELECT 'created' FROM fhir_create('{}'::jsonb, 'Patient',:'pt2_uuid'::uuid, :'pt2'::jsonb, :'pt2_tags'::jsonb);
SELECT 'created' FROM fhir_create('{}'::jsonb, 'DocumentReference',:'doc_ref_uuid'::uuid, :'doc_ref'::jsonb, '[]'::jsonb);

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by name')
  FROM search('Patient', 'name=roel');

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by identifier')
  FROM search('Patient', 'identifier=123456789');

SELECT build_search_query('Patient', 'identifier=MRN|7777777');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', 'identifier=MRN|7777777'))
 ,'pt found by mrn');

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by status')
  FROM search('Patient', 'active=true');

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by status')
  FROM search('Patient', 'active=true');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', 'telecom=+31612345678'))
 ,'pt found by phone');

/* SELECT build_search_query('Patient', 'telecom:missing=true'); */

/* SELECT assert_eq(:'pt2_uuid', */
/*  (SELECT string_agg(logical_id::text,'|') */
/*     FROM search('Patient', 'telecom:missing=true')) */
/*  ,'test missing true'); */

/* SELECT assert_eq(:'pt_uuid', */
/*  (SELECT string_agg(logical_id::text,'|') */
/*     FROM search('Patient', 'telecom:missing=false')) */
/*  ,'test missing false'); */


/* SELECT assert_eq(:'pt_uuid', */
/*  (SELECT string_agg(logical_id::text,',') */
/*     FROM search('Patient', 'gender=http://snomed.info/sct|248153007')) */
/*  ,'pt found by snomed gender'); */



/* SELECT assert_eq(:'org_uuid', */
/*  (SELECT logical_id */
/*     FROM search('Organization', 'name=Health%20Level')) */
/*  ,'org by name'); */

/* SELECT assert_eq(:'pt_uuid', */
/*  (SELECT logical_id */
/*     FROM search('Patient', 'provider.name=Health%20Level') LIMIT 1) */
/*  ,'pt by org name'); */

/* SELECT assert_eq(:'pt_uuid', */
/*  (SELECT logical_id */
/*     FROM search('Patient', 'name=Roelof&provider.name=Health%20Level')) */
/*  ,'pt by name & org name'); */


/* SELECT assert_eq(:'pt_uuid', */
/*  (SELECT logical_id */
/*     FROM search('Patient', 'family=bor') LIMIT 1) */
/*  ,'pt by family'); */

/* SELECT assert_eq(:'pt_uuid', */
/*  (SELECT logical_id */
/*     FROM search('Patient', 'family=bor&name=bor') LIMIT 1) */
/*  ,'pt by family & name'); */


/* SELECT assert_eq('http://pt/vip', */
/*  (SELECT string_agg(jsonb_array_elements#>>'{category,0,term}','') */
/*     FROM jsonb_array_elements( */
/*             fhir_search(:'cfg'::jsonb, */
/*               'Patient'::varchar, '_tag=http%3A%2F%2Fpt%2Fvip')->'entry')) */
/*  ,'pt by tag'); */

/* SELECT assert_eq(:'doc_ref_uuid', */
/*    (SELECT string_agg(logical_id::varchar, '|')), */
/*   'search number') */
/*   FROM search('DocumentReference', 'size=>100'); */

/* SELECT assert_eq(NULL, */
/*    (SELECT string_agg(logical_id::varchar, '|')), */
/*   'search number') */
/*   FROM search('DocumentReference', 'size=<100'); */

ROLLBACK;
--}}}

