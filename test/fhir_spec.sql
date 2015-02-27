-- #import ../src/tests.sql
-- #import ../src/fhir.sql

SET search_path TO fhir, vars, public;

BEGIN;

SELECT fhir.generate_tables('{Patient}');

setv('created',
  fhir.create('{}'::jsonb, '{"resourceType":"Patient", "id":"myid"}'::jsonb)
);

fhir.read('{}'::jsonb, 'myid') => getv('created')
fhir.read('{}'::jsonb, 'Patient/myid') => getv('created')

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
  fhir.create('{}'::jsonb, '{"resourceType":"Patient", "name":{"text":"Goga"}}'::jsonb)
);

expect 'id was set'
  SELECT (getv('without-id')->>'id') IS NOT NULL
=> true


expect 'meta respected in create'
  fhir.create('{}'::jsonb, '{"resourceType":"Patient", "meta":{"tags":[1]}}'::jsonb)#>'{meta,tags}'
=> '[1]'::jsonb

expect 'patient created'
  SELECT count(*) FROM patient
  WHERE logical_id = getv('without-id')->>'id'
=> 1::bigint

expect_raise 'id and meta.versionId are required'
  SELECT fhir.update('{}'::jsonb, '{"resourceType":"Patient", "id":"myid"}'::jsonb)

expect_raise 'expected last versionId'
  SELECT fhir.update('{}'::jsonb, '{"resourceType":"Patient", "id":"myid", "meta":{"versionId":"wrong"}}'::jsonb)

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 0::bigint

setv('updated',
  fhir.update('{}'::jsonb,
    jsonbext.assoc(getv('created'),'name','{"text":"Updated name"}')
  )
);

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 1::bigint

fhir.read('{}'::jsonb, 'myid')#>>'{name,text}' => 'Updated name'

fhir.vread('{}'::jsonb, getv('created')#>>'{meta,versionId}') => getv('created')

expect "latest"
  fhir.is_latest('{}'::jsonb, 'Patient', 'myid',
    getv('updated')#>>'{meta,versionId}')
=> true

expect "not latest"
  fhir.is_latest('{}'::jsonb, 'Patient', 'myid',
    getv('created')#>>'{meta,versionId}')
=> false

fhir.history('{}'::jsonb, 'Patient', 'myid')#>'{entry,0,resource}' => getv('updated')
fhir.history('{}'::jsonb, 'Patient', 'myid')#>'{entry,1,resource}' => getv('created')

expect '2 items for resource history'
  jsonb_array_length(
    fhir.history('{}'::jsonb, 'Patient', 'myid')->'entry'
  )
=> 2

expect '4 items for resource type history'
  jsonb_array_length(
    fhir.history('{}'::jsonb, 'Patient')->'entry'
  )
=> 4

expect 'more then 4 items for all history'
  jsonb_array_length(
    fhir.history('{}'::jsonb)->'entry'
  ) > 4
=> true

-- DELETE

fhir.is_exists('{}'::jsonb, 'Patient', 'myid') => true
fhir.is_deleted('{}'::jsonb, 'Patient', 'myid') => false

setv('deleted',
  fhir.delete('{}'::jsonb, 'Patient', 'myid')
);

expect_raise 'already deleted'
  SELECT fhir.delete('{}'::jsonb, 'Patient', 'myid')

expect_raise 'does not exist'
  SELECT fhir.delete('{}'::jsonb, 'Patient', 'nonexisting')

fhir.read('{}'::jsonb, 'myid') => null

fhir.is_exists('{}'::jsonb, 'Patient', 'myid') => false
fhir.is_deleted('{}'::jsonb, 'Patient', 'myid') => true

getv('deleted')#>>'{meta,versionId}' => getv('updated')#>>'{meta,versionId}'

ROLLBACK;
