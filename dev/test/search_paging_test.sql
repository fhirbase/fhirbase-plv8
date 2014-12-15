--db:fhirb
SET escape_string_warning=off;

--{{{
\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'
\set pt_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt2 `cat test/fixtures/pt2.json`
\set pt2_uuid '550e8400-e29b-41d4-a716-446655440011'
\set pt2_tags  '[{"scheme": "http://pt.com", "term": "http://pt/noise", "label":"noise"}]'

\set cfg '{"base":"https://test.me"}'

BEGIN;

SELECT 'created' FROM fhir_create('{}'::jsonb, 'Patient', :'pt_uuid'::uuid, :'pt'::jsonb, :'pt_tags'::jsonb);
SELECT 'created' FROM fhir_create('{}'::jsonb, 'Patient', :'pt2_uuid'::uuid, :'pt2'::jsonb, :'pt2_tags'::jsonb);

SELECT build_search_query('Patient', '_count=50&_page=3');

SELECT build_search_query('Patient','_count=50&_page=3&_sort=birthdate');

SELECT build_search_query('Patient', '_count=1');


SELECT assert_eq('1',
(
    SELECT COUNT(*)::varchar
      FROM search('Patient', '_count=1')
), 'search respects _count option');


SELECT assert_eq(:'pt_uuid',
(
  SELECT string_agg(logical_id::varchar, '|')
  FROM search('Patient', '_count=1&_page=0&_sort=birthdate')
), 'search next page respects _count and _page option');


SELECT assert_eq(:'pt2_uuid',
(
  SELECT string_agg(logical_id::varchar, '')
  FROM search('Patient', 'gender=M&_count=1&_page=0&_sort:desc=birthdate')
), 'search with gender respects _count and _page option');


SELECT assert_eq((:'pt_uuid' || '|' || :'pt2_uuid'),
(
  SELECT string_agg(logical_id::varchar, '|')
    FROM search('Patient', '_sort:desc=given')
), 'search respects _sort option');


SELECT build_search_query('Patient', 'gender=M&_sort:asc=given');

SELECT assert_eq((:'pt2_uuid' || '|' || :'pt_uuid'),
(
  SELECT string_agg(logical_id::varchar, '|')
    FROM search('Patient', '_sort:asc=given')
), 'search respects _sort inverse option');


/* SELECT  build_search_query('Patient', 'gender=M&_sort:desc=gender&_sort=birthdate'); */

/* SELECT assert_eq(:'pt_uuid', */
/* ( */
/*   SELECT string_agg(logical_id::varchar, '|') */
/*     FROM search('Patient', 'gender=M&_sort:desc=gender&_sort=birthdate&_count=1') */
/* ), 'search should combine several _sort columns'); */

ROLLBACK;
--}}}
