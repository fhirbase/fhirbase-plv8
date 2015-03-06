-- #import ../src/tests.sql
-- #import ../src/crud.sql
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


-- expect 'generate id by sha'
--   gen_version_id('{"resourceType":"Patient", "name":{"text":"Goga"}, "meta": {"tags":["ups"]}}'::jsonb)
-- => gen_version_id('{"name":{"text":"Goga"}, "resourceType":"Patient"}'::jsonb)

-- expect 'generate id by sha'
--   gen_logical_id('{"resourceType":"Patient", "name":{"text":"Goga"}, "meta": {"tags":["ups"]}}'::jsonb)
-- => gen_logical_id('{"name":{"text":"Goga"}, "resourceType":"Patient"}'::jsonb)

BEGIN;

SELECT generate.generate_tables('{Patient}');

setv('created',
  crud.create('{}'::jsonb, '{"resourceType":"Patient", "id":"myid"}'::jsonb)
);

crud.read('{}'::jsonb, 'myid') => getv('created')
crud.read('{}'::jsonb, 'Patient/myid') => getv('created')

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
  crud.create('{}'::jsonb, '{"resourceType":"Patient", "name":{"text":"Goga"}}'::jsonb)
);

expect 'id was set'
  SELECT (getv('without-id')->>'id') IS NOT NULL
=> true


expect 'meta respected in create'
  crud.create('{}'::jsonb, '{"resourceType":"Patient", "meta":{"tags":[1]}}'::jsonb)#>'{meta,tags}'
=> '[1]'::jsonb

expect 'patient created'
  SELECT count(*) FROM patient
  WHERE logical_id = getv('without-id')->>'id'
=> 1::bigint

expect_raise 'id and meta.versionId are required'
  SELECT crud.update('{}'::jsonb, '{"resourceType":"Patient", "id":"myid"}'::jsonb)

expect_raise 'expected last versionId'
  SELECT crud.update('{}'::jsonb, '{"resourceType":"Patient", "id":"myid", "meta":{"versionId":"wrong"}}'::jsonb)

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 0::bigint

setv('updated',
  crud.update('{}'::jsonb,
    jsonbext.assoc(getv('created'),'name','{"text":"Updated name"}')
  )
);

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 1::bigint

crud.read('{}'::jsonb, 'myid')#>>'{name,text}' => 'Updated name'

crud.vread('{}'::jsonb, getv('created')#>>'{meta,versionId}') => getv('created')

expect "latest"
  crud.is_latest('{}'::jsonb, 'Patient', 'myid',
    getv('updated')#>>'{meta,versionId}')
=> true

expect "not latest"
  crud.is_latest('{}'::jsonb, 'Patient', 'myid',
    getv('created')#>>'{meta,versionId}')
=> false

crud.history('{}'::jsonb, 'Patient', 'myid')#>'{entry,0,resource}' => getv('updated')
crud.history('{}'::jsonb, 'Patient', 'myid')#>'{entry,1,resource}' => getv('created')

expect '2 items for resource history'
  jsonb_array_length(
    crud.history('{}'::jsonb, 'Patient', 'myid')->'entry'
  )
=> 2

expect '4 items for resource type history'
  jsonb_array_length(
    crud.history('{}'::jsonb, 'Patient')->'entry'
  )
=> 4

expect 'more then 4 items for all history'
  jsonb_array_length(
    crud.history('{}'::jsonb)->'entry'
  ) > 4
=> true

-- DELETE

crud.is_exists('{}'::jsonb, 'Patient', 'myid') => true
crud.is_deleted('{}'::jsonb, 'Patient', 'myid') => false

setv('deleted',
  crud.delete('{}'::jsonb, 'Patient', 'myid')
);

expect_raise 'already deleted'
  SELECT crud.delete('{}'::jsonb, 'Patient', 'myid')

expect_raise 'does not exist'
  SELECT crud.delete('{}'::jsonb, 'Patient', 'nonexisting')

crud.read('{}'::jsonb, 'myid') => null

crud.is_exists('{}'::jsonb, 'Patient', 'myid') => false
crud.is_deleted('{}'::jsonb, 'Patient', 'myid') => true

getv('deleted')#>>'{meta,versionId}' => getv('updated')#>>'{meta,versionId}'

/* expect */
/*   SELECT E'\n' || string_agg(ROW(x.*)::text, E'\n') FROM patient x */
/* => '' */

ROLLBACK;
