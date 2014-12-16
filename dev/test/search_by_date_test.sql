--db:fhirb
--{{{

\set pt_uuid '550e8400-e29b-41d4-a716-44665544001'

BEGIN;
SELECT 'created'
FROM fhir_create('{}'::jsonb, 'Patient',
  (:'pt_uuid' || '1')::uuid,
  '{"birthDate":"1973"}'::jsonb, null);

SELECT 'created'
FROM fhir_create('{}'::jsonb, 'Patient',
  (:'pt_uuid' || '2')::uuid,
  '{"birthDate":"1983"}'::jsonb, null);

SELECT 'created'
FROM fhir_create('{}'::jsonb, 'Patient',
  (:'pt_uuid' || '3')::uuid,
  '{"birthDate":"1993"}'::jsonb, null);

SELECT assert_eq((:'pt_uuid' || '1'),
 (SELECT string_agg(logical_id::text,',')
    FROM search('Patient', 'birthdate=1973'))
 ,'pt found birthdate');

SELECT assert_eq((:'pt_uuid' || '2'),
 (SELECT string_agg(logical_id::text,',')
    FROM search('Patient', 'birthdate=1983'))
 ,'pt found birthdate');

SELECT assert_eq(2::bigint,
 (SELECT count(*)
    FROM search('Patient', 'birthdate=>1980'))
 ,'pt found birthdate');

SELECT assert_eq(3::bigint,
 (SELECT count(*)
    FROM search('Patient', 'birthdate=>1970'))
 ,'pt found birthdate');

SELECT assert_eq(1::bigint,
 (SELECT count(*)
    FROM search('Patient', 'birthdate=<1980'))
 ,'pt found birthdate');

SELECT assert_eq(2::bigint,
 (SELECT count(*)
    FROM search('Patient', 'birthdate=<1990'))
 ,'pt found birthdate');

ROLLBACK;

--}}}
