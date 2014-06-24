--db:fhirb -e
SET escape_string_warning=off;
--{{{
\set org1 `cat test/fixtures/org1.json`
\set pt `cat test/fixtures/pt.json`
\set org_uuid '550e8400-e29b-41d4-a716-446655440009'
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'

BEGIN;

SELECT insert_resource(:'org_uuid'::uuid, :'org1'::jsonb, '[]'::jsonb);
SELECT insert_resource(:'pt_uuid'::uuid, :'pt'::jsonb, '[]'::jsonb);


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


ROLLBACK;
--}}}
