-- #import ../src/tests.sql
-- #import ../src/fhirbase_crud.sql
SET search_path TO fhirbase_crud, vars, public;

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


-- expect 'generate id by sha'
--   gen_version_id('{"resourceType":"Patient", "name":{"text":"Goga"}, "meta": {"tags":["ups"]}}'::jsonb)
-- => gen_version_id('{"name":{"text":"Goga"}, "resourceType":"Patient"}'::jsonb)

-- expect 'generate id by sha'
--   gen_logical_id('{"resourceType":"Patient", "name":{"text":"Goga"}, "meta": {"tags":["ups"]}}'::jsonb)
-- => gen_logical_id('{"name":{"text":"Goga"}, "resourceType":"Patient"}'::jsonb)

BEGIN;

SELECT fhirbase_generate.generate_tables('{Patient}');

expect_raise 'resource id should be empty'
  SELECT fhirbase_crud.create('{}'::jsonb, '{"resourceType":"Patient", "id":"myid"}'::jsonb)

ROLLBACK;

BEGIN;

SELECT fhirbase_generate.generate_tables('{Patient}');

setv('created',
  fhirbase_crud.update('{}'::jsonb, '{"resourceType":"Patient", "id":"myid"}'::jsonb)
);

fhirbase_crud.read('{}'::jsonb, 'myid') => getv('created')
fhirbase_crud.read('{}'::jsonb, 'Patient/myid') => getv('created')

expect 'id is myid'
  getv('created')->>'id'
=> 'myid'

expect 'patient in table'
  SELECT count(*) FROM patient
  WHERE logical_id = 'myid'
=> 1::bigint

expect 'meta info'
  jsonb_typeof(getv('created')->'meta')
=> 'object'

expect 'meta info'
  jsonb_typeof(getv('created')#>'{meta,versionId}')
=> 'string'

expect 'meta info'
  jsonb_typeof(getv('created')#>'{meta,lastUpdated}')
=> 'string'

setv('without-id',
  fhirbase_crud.create('{}'::jsonb, '{"resourceType":"Patient", "name":{"text":"Goga"}}'::jsonb)
);

expect 'id was set'
  SELECT (getv('without-id')->>'id') IS NOT NULL
=> true


expect 'meta respected in create'
  fhirbase_crud.create('{}'::jsonb, '{"resourceType":"Patient", "meta":{"tags":[1]}}'::jsonb)#>'{meta,tags}'
=> '[1]'::jsonb

expect 'patient created'
  SELECT count(*) FROM patient
  WHERE logical_id = getv('without-id')->>'id'
=> 1::bigint

expect_raise 'expected last versionId'
  SELECT fhirbase_crud.update('{}'::jsonb, '{"resourceType":"Patient", "id":"myid", "meta":{"versionId":"wrong"}}'::jsonb)

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 0::bigint

setv('updated',
  fhirbase_crud.update('{}'::jsonb,
    fhirbase_json.assoc(getv('created'),'name','{"text":"Updated name"}')
  )
);

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 1::bigint

fhirbase_crud.read('{}'::jsonb, 'myid')#>>'{name,text}' => 'Updated name'

fhirbase_crud.vread('{}'::jsonb, getv('created')#>>'{meta,versionId}') => getv('created')

expect "latest"
  fhirbase_crud.is_latest('{}'::jsonb, 'Patient', 'myid',
    getv('updated')#>>'{meta,versionId}')
=> true

expect "not latest"
  fhirbase_crud.is_latest('{}'::jsonb, 'Patient', 'myid',
    getv('created')#>>'{meta,versionId}')
=> false

-- DELETE

fhirbase_crud.is_exists('{}'::jsonb, 'Patient', 'myid') => true
fhirbase_crud.is_deleted('{}'::jsonb, 'Patient', 'myid') => false

setv('deleted',
  fhirbase_crud.delete('{}'::jsonb, 'Patient', 'myid')
);

expect_raise 'already deleted'
  SELECT fhirbase_crud.delete('{}'::jsonb, 'Patient', 'myid')

expect_raise 'does not exist'
  SELECT fhirbase_crud.delete('{}'::jsonb, 'Patient', 'nonexisting')

fhirbase_crud.read('{}'::jsonb, 'myid') => null

fhirbase_crud.is_exists('{}'::jsonb, 'Patient', 'myid') => false
fhirbase_crud.is_deleted('{}'::jsonb, 'Patient', 'myid') => true

getv('deleted')#>>'{meta,versionId}' => getv('updated')#>>'{meta,versionId}'

/* expect */
/*   SELECT E'\n' || string_agg(ROW(x.*)::text, E'\n') FROM patient x */
/* => '' */

ROLLBACK;
