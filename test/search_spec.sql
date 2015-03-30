-- #import ../src/tests.sql
-- #import ../src/fhirbase_search.sql
-- #import ../src/fhirbase_generate.sql
-- #import ../src/fhirbase_crud.sql

SET search_path TO fhirbase_search, vars, public;

build_sorting('Patient', '_sort=given') =>  E'\n ORDER BY (fhirbase_json.json_get_in(patient.content, \'{name,given}\'))[1]::text ASC'

SELECT logical_id FROM search('StructureDefinition', 'name=Patient&_count=1') => 'Patient'
SELECT count(*) FROM search('SearchParameter', 'base=Patient') => 17::bigint

BEGIN;


SELECT fhirbase_generate.generate_tables('{Patient, Encounter}');

SELECT fhirbase_crud.create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1973"}'::jsonb);
SELECT fhirbase_crud.create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1983"}'::jsonb);
SELECT fhirbase_crud.create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1993"}'::jsonb);

SELECT count(*) FROM search('Patient', 'birthdate=>1970') => 3::bigint
SELECT count(*) FROM search('Patient', 'birthdate=>1980') => 2::bigint
SELECT count(*) FROM search('Patient', 'birthdate=>1990') => 1::bigint

expect 'search by _id'
  SELECT count(*) FROM search(
    'Patient',
    '_id=' || (SELECT logical_id FROM search('Patient', 'birthdate=>1990') LIMIT 1)
  )
=> 1::bigint

expect '_id condition'
  SELECT fhir.search_sql('Patient', '_id=1') ilike '%.logical_id IN (%'
=> true

--TODO: test chained params
--expect 'chained _id condition'
--SELECT fhir.search_sql('Encounter', 'patient._id=1') /*ilike 'patient.logical_id IN (%'*/
--=> 'ups'

ROLLBACK;

BEGIN;

SELECT fhirbase_generate.generate_tables('{Patient}');

setv('cfg','{"base":"https://test.me"}'::jsonb);

setv('pt-tpl', '{"resourceType":"Patient", "gender":"%s", "birthDate":"%s"}');

SELECT fhirbase_crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'mail', '1970')::jsonb);
SELECT fhirbase_crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'mail', '1980')::jsonb);
SELECT fhirbase_crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'femail', '1985')::jsonb);
SELECT fhirbase_crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'femail', '1990')::jsonb);

SELECT build_search_query('Patient', '_count=50&_page=3');

SELECT build_search_query('Patient','_count=50&_page=3&_sort=birthdate');

SELECT build_search_query('Patient', '_count=1');

SELECT count(*) FROM search('Patient', '_count=1') => 1::bigint
SELECT count(*) FROM search('Patient', '_count=2') => 2::bigint
SELECT count(*) FROM search('Patient', '_count=3') => 3::bigint



SELECT content->>'birthDate' FROM search('Patient', '_count=1&_sort=birthdate') => '1970'
SELECT content->>'birthDate' FROM search('Patient', '_count=1&_sort:desc=birthdate') => '1990'
SELECT content->>'birthDate' FROM search('Patient', '_sort:desc=gender&_count=1&_page=1&_sort:desc=birthdate') => '1970'

ROLLBACK;

BEGIN;

SELECT fhirbase_generate.generate_tables('{Device}');

setv('cfg', '{"base":"https://test.me"}');
setv('device', '{"resourceType": "Device", "model": "Jóe", "manufacturer": "Acme" }');

setv('dev',
  fhirbase_crud.create(getv('cfg'), getv('device'))
);

expect
  fhir_search(getv('cfg'), 'Device', '')#>>'{resourceType}'
=> 'Bundle'

expect
  fhir_search(getv('cfg'), 'Device', 'model=Joe')#>>'{entry,0,resource,resourceType}'
=> 'Device'

expect
  fhir_search(getv('cfg'), 'Device', 'manufacturer=Ácme')#>>'{entry,0,resource,resourceType}'
=> 'Device'

expect
  fhir_search(getv('cfg'), 'Device', 'model=Jóe')#>>'{entry,0,resource,resourceType}'
=> 'Device'

ROLLBACK;

BEGIN;

SELECT fhirbase_generate.generate_tables('{Organization}');

setv('cfg', '{"base":"https://test.me"}');
setv('organization', '{"resourceType": "Organization", "name": "policlinic 6" }');

setv('org', fhirbase_crud.create(getv('cfg'), getv('organization')));

expect
  fhir_search(getv('cfg'), 'Organization', 'name:exact=policlinic')#>>'{entry,0,resource}'
=> null

ROLLBACK;
