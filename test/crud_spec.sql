-- #import ../src/tests.sql
-- #import ../src/fhir/crud.sql
SET search_path TO crud, vars, public;

_build_url('{"base":"base"}', 'a','b','c') => 'base/a/b/c'

_build_url('{"base":"base"}', 'a',1::text,'c') => 'base/a/1/c'

expect
  _build_link('{"base":"base"}', 'Patient','a9c6bcbe-3319-47dc-8e68-6cd318f79b94','fba704fc-32f9-4f57-ae92-4c767c672b07')
=>  '{"rel": "self", "href": "base/Patient/a9c6bcbe-3319-47dc-8e68-6cd318f79b94/_history/fba704fc-32f9-4f57-ae92-4c767c672b07"}'::jsonb

_build_id('{"base":"base"}', 'Patient','a9c6bcbe-3319-47dc-8e68-6cd318f79b94') => 'base/Patient/a9c6bcbe-3319-47dc-8e68-6cd318f79b94'::text

_extract_id('rid/_history/vid') => 'rid'

_extract_id('http://ups/rid/_history/vid') => 'rid'

_extract_vid('rid/_history/vid') => 'vid'

_extract_vid('http://ups/rid/_history/vid') => 'vid'


BEGIN;

SELECT generate.generate_tables('{Patient}');

setv('cfg','{"base":"https://test.me"}'::jsonb);
setv('ptj','{"resourceType":"Patient","name":{"text":"Goga"}}'::jsonb);
setv('uptj','{"resourceType":"Patient","name":{"text":"Magoga"}}'::jsonb);

setv('ipt',
  fhir_create(getv('cfg'), 'Patient', getv('ptj'),null)#>'{entry,0}'
);

setv('upt',
  fhir_update(
    getv('cfg'), 'Patient',
    getv('ipt')#>>'{id}',
    getv('ipt')#>>'{link,0,href}',
    getv('uptj'),
    null
  )#>'{entry,0}'
);

getv('upt')->'content' => getv('uptj')

SELECT count(*) FROM patient => 1::bigint
SELECT count(*) FROM patient_history => 1::bigint

expect 'history'
  jsonb_array_length(
    fhir_history(getv('cfg'), 'Patient', getv('ipt')#>>'{id}', '{}'::jsonb)->'entry'
  )
=> 2

expect 'history resource'
  jsonb_array_length(
    fhir_history(getv('cfg'), 'Patient', null)->'entry'
  )
=> 2

expect 'history all resources'
  jsonb_array_length(
    fhir_history(getv('cfg'), null)->'entry'
  )
=> 2

expect
  fhir_is_latest_resource(
    getv('cfg'),
    'Patient',
    getv('upt')->>'id',
    getv('ipt')#>>'{link,0,href}'
  )
=> false

expect
  fhir_is_latest_resource(
    getv('cfg'),
    'Patient',
    getv('upt')->>'id',
    getv('upt')#>>'{link,0,href}'
  )
=> true

expect
  fhir_is_deleted_resource(
    getv('cfg'),
    'Patient',
    getv('upt')->>'id'
  )
=> false

SELECT fhir_delete( getv('cfg'), 'Patient', getv('upt')->>'id');

expect
  fhir_is_deleted_resource(
    getv('cfg'),
    'Patient',
    getv('upt')->>'id'
  )
=> true

SELECT count(*) from patient => 0::bigint

ROLLBACK;
