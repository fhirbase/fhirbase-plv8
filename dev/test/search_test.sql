--db:fhirb -e
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

BEGIN;

SELECT insert_resource(:'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);
SELECT insert_resource(:'pt2_uuid'::uuid, :'pt2'::jsonb, :'pt2_tags'::jsonb);

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
    FROM search('Patient', '{"provider.name": "Health Level"}') LIMIT 1)
 ,'pt by org name');

SELECT assert_eq(:'pt_uuid',
 (SELECT logical_id
    FROM search('Patient', '{"name": "Roelof",  "provider.name": "Health Level"}'))
 ,'pt by name & org name');

SELECT assert_eq('http://pt/vip',
 (SELECT string_agg(jsonb_array_elements#>>'{category,0,term}','')
    FROM jsonb_array_elements(
            fhir_search('Patient', '{"_tag": "http://pt/vip"}')->'entry'))
 ,'pt by tag');


-- TESTS ON _count, _sort and _page
-------------------------------------------------
SELECT assert_eq('1', (SELECT COUNT(*)::varchar), 'search respects _count option')
  FROM search('Patient', '{"_count": 1}');

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


ROLLBACK;
--}}}
