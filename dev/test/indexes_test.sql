--db:fhirb -e

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
'index_identifier_as_token')
--}}}
