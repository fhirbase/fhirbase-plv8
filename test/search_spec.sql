-- #import ../src/tests.sql
-- #import ../src/fhir/search.sql
-- #import ../src/fhir/generate.sql
-- #import ../src/fhir/crud.sql

SET search_path TO search, vars, public;

build_sorting('Patient', '_sort=given') =>  E'\n ORDER BY (jsonbext.json_get_in(patient.content, \'{name,given}\'))[1]::text ASC'

BEGIN;


SELECT generate.generate_base_tables();
SELECT generate.generate_tables('{Patient}');

SELECT crud.create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1973"}'::jsonb);
SELECT crud.create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1983"}'::jsonb);
SELECT crud.create('{}'::jsonb, '{"resourceType":"Patient","birthDate":"1993"}'::jsonb);

SELECT count(*) FROM search('Patient', 'birthdate=>1970') => 3::bigint
SELECT count(*) FROM search('Patient', 'birthdate=>1980') => 2::bigint
SELECT count(*) FROM search('Patient', 'birthdate=>1990') => 1::bigint


ROLLBACK;

BEGIN;

SELECT generate.generate_base_tables();
SELECT generate.generate_tables('{Patient}');

setv('cfg','{"base":"https://test.me"}'::jsonb);

setv('pt-tpl', '{"resourceType":"Patient", "gender":"%s", "birthDate":"%s"}');

SELECT crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'mail', '1970')::jsonb);
SELECT crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'mail', '1980')::jsonb);
SELECT crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'femail', '1985')::jsonb);
SELECT crud.create(getv('cfg'), format(getv('pt-tpl')::text, 'femail', '1990')::jsonb);

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

SELECT generate.generate_base_tables();
SELECT generate.generate_tables('{Device}');

setv('cfg', '{"base":"https://test.me"}');
setv('device', '{"resourceType": "Device", "model": "Jóe", "manufacturer": "Acme" }');

setv('dev',
  crud.create(getv('cfg'), getv('device'))
);

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
