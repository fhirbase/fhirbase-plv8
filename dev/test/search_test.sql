--db:fhirb -e
SET escape_string_warning=off;
--{{{
SELECT *
  FROM build_search_query('Patient'::text,
                     json_build_object('provider._id', '1,2',
                                       'provider.name', 'ups',
                                       '_id', '1,2',
                                       '_page', 10,
                                       'birthdate:missing', true,
                                       'identifier', 'MRN|7777777',
                                       '_count', 100,
                                       '_sort', ARRAY['name:desc', 'address:asc'],
                                       'name', 'pups')::jsonb);
SELECT *
  FROM _expand_search_params('Patient'::text,
                     json_build_object('provider._id', '1,2',
                                       'provider.name', 'ups',
                                       'name', 'pups')::jsonb);

SELECT *
  FROM _build_references_joins('Patient'::text,
                     json_build_object('provider._id', '1,2',
                                       'name', 'pups')::jsonb);
SELECT *
  FROM build_search_joins('Patient'::text,
                     json_build_object('provider._id', '1,2',
                                       'provider.name', 'ups',
                                       'name', 'pups')::jsonb);

--}}}
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

SELECT insert_resource(:'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);
SELECT insert_resource(:'pt2_uuid'::uuid, :'pt2'::jsonb, :'pt2_tags'::jsonb);
SELECT insert_resource(:'doc_ref_uuid'::uuid, :'doc_ref'::jsonb, '[]'::jsonb);

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by name')
  FROM search('Patient', '{"name": "roel"}');

SELECT assert_eq(:'pt_uuid', logical_id, 'pt found by identifier')
  FROM search('Patient', '{"identifier": "123456789"}');

SELECT build_search_query('Patient', '{"identifier": "MRN|7777777"}');

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

SELECT build_search_query('Patient', '{"telecom:missing": "true"}');

SELECT assert_eq(:'pt2_uuid',
 (SELECT string_agg(logical_id::text,'|')
    FROM search('Patient', '{"telecom:missing": "true"}'))
 ,'test missing true');

SELECT assert_eq(:'pt_uuid',
 (SELECT string_agg(logical_id::text,'|')
    FROM search('Patient', '{"telecom:missing": "false"}'))
 ,'test missing false');


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
    FROM search('Patient', '{"provider.name": "Health Level"}') LIMIT 1)
 ,'pt by org name');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"name": "Roelof",  "provider.name": "Health Level"}'))
 ,'pt by name & org name');


SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"family": "bor"}') LIMIT 1)
 ,'pt by family');


SELECT assert_eq('http://pt/vip',
 (SELECT string_agg(jsonb_array_elements#>>'{category,0,term}','')
    FROM jsonb_array_elements(
            fhir_search(:'cfg'::jsonb,
              'Patient'::varchar, '{"_tag": "http://pt/vip"}'::jsonb)->'entry'))
 ,'pt by tag');


-- TESTS ON _count, _sort and _page
-------------------------------------------------
SELECT assert_eq('1', (SELECT COUNT(*)::varchar), 'search respects _count option')
  FROM search('Patient', '{"_count": 1}');

SELECT build_search_query('Patient', '{"_count": 1, "_page": 1, "_sort": ["birthdate"]}');
SELECT assert_eq(:'pt2_uuid', (SELECT string_agg(logical_id::varchar, '')),
                 'search respects _count and _page option')
  FROM search('Patient', '{"_count": 1, "_page": 1, "_sort": ["birthdate"]}');

SELECT assert_eq(:'pt2_uuid', (SELECT string_agg(logical_id::varchar, '')),
  'search respects _count and _page option')
  FROM search('Patient', '{"gender": "M", "_count": 1, "_page": 0, "_sort": ["birthdate:desc"]}');


SELECT assert_eq(:'pt2_uuid' || :'pt_uuid', (SELECT string_agg(logical_id::varchar, '')),
  'search respects _sort option')
  FROM search('Patient', '{"gender": "M", "_sort": ["birthdate:desc"]}');

SELECT assert_eq(:'pt_uuid' || '|' || :'pt2_uuid', (SELECT string_agg(logical_id::varchar, '|')),
  'search respects _sort option')
  FROM search('Patient', '{"gender": "M", "_sort": ["birthdate:asc"]}');


SELECT assert_eq(:'pt_uuid' || '|' || :'pt2_uuid', (SELECT string_agg(logical_id::varchar, '|')),
  'search should combine several _sort columns')
  FROM search('Patient', '{"gender": "M", "_sort": ["gender:desc", "birthdate:asc"]}');


-- TESTS ON _include
-------------------------------------------------

SELECT assert_eq(:'org_uuid' || '|' || :'pt_uuid', (SELECT string_agg(logical_id::varchar, '|')),
  'search should include resources specified in _include')
  FROM search('Patient', '{"name": "Roel", "_include": ["Patient.managingOrganization"]}');

SELECT assert_eq(:'pt_uuid', (SELECT string_agg(logical_id::varchar, '|')),
  'search should ignore wrong paths in _include')
  FROM search('Patient', '{"name": "Roel", "_include": ["Patient.foobar"]}');


SELECT assert_eq(:'doc_ref_uuid',
   (SELECT string_agg(logical_id::varchar, '|')),
  'search number')
  FROM search('DocumentReference', '{"size":">100"}');

SELECT assert_eq(NULL,
   (SELECT string_agg(logical_id::varchar, '|')),
  'search number')
  FROM search('DocumentReference', '{"size":"<100"}');
;



ROLLBACK;
--}}}

--{{{
-- testing _ids

\set org1 `cat test/fixtures/org1.json`
\set org_uuid '550e8400-e29b-41d4-a716-446655440009'
\set org_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'
\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'
\set pt_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt2 `cat test/fixtures/pt2.json`
\set pt2_uuid '550e8400-e29b-41d4-a716-446655440011'
\set pt2_tags  '[{"scheme": "http://pt.com", "term": "http://pt/noise", "label":"noise"}]'

BEGIN;

SELECT insert_resource(:'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);
SELECT insert_resource(:'pt2_uuid'::uuid, :'pt2'::jsonb, :'pt2_tags'::jsonb);

SELECT assert_eq(:'pt_uuid',
  (SELECT string_agg(logical_id::varchar, '|')),
  'search by _id')
  FROM search('Patient', json_build_object('_id', :'pt_uuid')::jsonb);

SELECT assert_eq(:'pt_uuid',
  (SELECT string_agg(logical_id::varchar, '|')),
  'chained search by provider._id')
  FROM search('Patient', json_build_object('provider._id', :'org_uuid')::jsonb);


ROLLBACK;
--}}}
