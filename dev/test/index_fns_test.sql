--db:fhirb
--{{{
\set pt `cat test/fixtures/pt.json`

SELECT assert_eq(
(SELECT index_as_reference(:'pt'::jsonb,  '{managingOrganization}'::varchar[])),
'{550e8400-e29b-41d4-a716-446655440009,Organization/550e8400-e29b-41d4-a716-446655440009}',
'index reference');


/* SELECT index_as_string(:'pt'::jsonb,  '{name}'::varchar[]); */

SELECT assert_eq(
(SELECT
  regexp_matches(
  index_as_string(:'pt'::jsonb,  '{name}'::varchar[]),
  'Roel')),
'{Roel}'::text[],
'index_as_string');
--}}}
