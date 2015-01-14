\set doc_ref `cat test/fixtures/documentreference-example.json`
\set doc_ref_uuid '550e8400-e29b-41d4-a716-446655440012'
\set cfg '{"base":"https://test.me"}'

BEGIN;

SELECT fhir_create('{}'::jsonb, 'DocumentReference',:'doc_ref_uuid'::uuid, :'doc_ref'::jsonb, '[]'::jsonb);

-- TODO:  uncomment spec
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

