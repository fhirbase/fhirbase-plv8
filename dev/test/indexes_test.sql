--db:fhirb

SET escape_string_warning=off;
--{{{
\set obs `cat test/fixtures/observation.json`

SELECT assert_eq(
(SELECT index_primitive_as_token('{"a":[{"b":1},{"b":2}]}','{a,b}')),
'{1,2}'::varchar[],
'index_primitive_as_token');

SELECT assert_eq(
(SELECT index_primitive_as_token(:'obs','{status}')),
'{final}'::varchar[],
'index_primitive_as_token');
--}}}

--{{{
\set obs `cat test/fixtures/observation.json`

SELECT assert_eq(
(SELECT index_codeableconcept_as_token(:'obs','{name}')),
 '{custom|GLU,http://loinc.org|2339-0,2339-0,GLU}'::varchar[],
'index_codeable_concept_as_token');
--}}}

--{{{
\set obs `cat test/fixtures/observation.json`

SELECT assert_eq(
(SELECT index_coding_as_token(:'obs','{name,coding}')),
 '{custom|GLU,http://loinc.org|2339-0,2339-0,GLU}'::varchar[],
 'index_coding_as_token');
--}}}

--{{{
\set pt `cat test/fixtures/pt.json`

SELECT assert_eq(
(SELECT index_identifier_as_token(:'pt','{identifier}')),
 '{urn:oid:2.16.840.1.113883.2.4.6.3|123456789,MRN|7777777,7777777,123456789}'::varchar[],
'index_identifier_as_token');
--}}}

--{{{
\set pt `cat test/fixtures/pt.json`

SELECT assert_eq(
(SELECT index_as_string(:'pt','{name}')::text ilike '%Roel%'),
true,
'index_as_string');

SELECT assert_eq(
(SELECT index_as_string(:'pt','{name}')::text ilike '%Bor%'),
true,
'index_as_string');
--}}}

--{{{
\set pt `cat test/fixtures/pt.json`

SELECT assert_eq(
(SELECT index_as_reference(format(:'pt', '550e8400-e29b-41d4-a716-446655440009')::jsonb,  '{managingOrganization}'::varchar[])),
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

SELECT drop_all_resource_indexes();
SELECT index_search_param('Patient','name');
SELECT drop_index_search_param('Patient','name');
SELECT index_all_resources();

--}}}
