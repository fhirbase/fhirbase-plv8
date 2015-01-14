BEGIN;

SELECT fhir_create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1973"}'::jsonb);
SELECT fhir_create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1983"}'::jsonb);
SELECT fhir_create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1993"}'::jsonb);

SELECT count(*) FROM search('Patient', 'birthdate=>1970') => 3::bigint
SELECT count(*) FROM search('Patient', 'birthdate=>1980') => 2::bigint
SELECT count(*) FROM search('Patient', 'birthdate=>1990') => 1::bigint


ROLLBACK;
