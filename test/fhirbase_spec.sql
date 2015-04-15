-- #import ../src/tests.sql
-- #import ../src/fhir.sql

SET search_path TO fhir, vars, public;

BEGIN;

SELECT fhirbase_generate.generate_tables('{Patient,Flag,Device}');

setv('created',
  fhir.update( '{"resourceType":"Patient", "id":"myid"}'::jsonb)
);

fhir.read('Patient', 'myid') => getv('created')
fhir.read('Patient', 'Patient/myid') => getv('created')

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
  fhir.create( '{"resourceType":"Patient", "name":{"text":"Goga"}}'::jsonb)
);

expect 'id was set'
  SELECT (getv('without-id')->>'id') IS NOT NULL
=> true


expect 'meta respected in create'
  fhir.create( '{"resourceType":"Patient", "meta":{"tags":[1]}}'::jsonb)#>'{meta,tags}'
=> '[1]'::jsonb

expect 'patient created'
  SELECT count(*) FROM patient
  WHERE logical_id = getv('without-id')->>'id'
=> 1::bigint

setv('updateWithoutId',
  fhir.update('{"resourceType":"Patient"}')
);

getv('updateWithoutId')->>'resourceType' => 'OperationOutcome'
getv('updateWithoutId')#>>'{issue,0,code,coding,1,code}' => '422'

expect 'outcome with wrong version id'
  fhirbase_crud.update( '{}'::jsonb,
    '{"resourceType":"Patient", "id":"myid", "meta":{"versionId":"wrong"}}'::jsonb
  )#>>'{issue,0,code,coding,1,code}'
=> '422'

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 0::bigint

SELECT pg_sleep(1);

setv('updated',
  fhir.update(
    fhirbase_json.assoc(getv('created'),'name','{"text":"Updated name"}')
  )
);

--SELECT tests._debug(fhir.history('Patient', 'myid'));

expect 'updated'
  SELECT count(*) FROM patient_history
  WHERE logical_id = 'myid'
=> 1::bigint

fhir.read('Patient', 'myid')#>>'{name,text}' => 'Updated name'

fhir.vread('Patient', getv('created')#>>'{meta,versionId}') => getv('created')

expect "latest"
  fhir.is_latest( 'Patient', 'myid',
    getv('updated')#>>'{meta,versionId}')
=> true

expect "not latest"
  fhir.is_latest( 'Patient', 'myid',
    getv('created')#>>'{meta,versionId}')
=> false

fhir.history( 'Patient', 'myid', '')#>'{entry,0,resource}' => getv('updated')
fhir.history( 'Patient', 'myid', '')#>'{entry,1,resource}' => getv('created')

expect '2 items for resource history'
  jsonb_array_length(
    fhir.history( 'Patient', 'myid', '')->'entry'
  )
=> 2

expect '4 items for resource type history'
  jsonb_array_length(
    fhir.history( 'Patient', '')->'entry'
  )
=> 4

expect 'more then 4 items for all history'
  jsonb_array_length(
    fhir.history('')->'entry'
  ) > 4
=> true

-- DELETE

fhir.is_exists( 'Patient', 'myid') => true
fhir.is_deleted( 'Patient', 'myid') => false

setv('deleted',
  fhir.delete( 'Patient', 'myid')
);

fhir.delete('Patient', 'myid')#>>'{issue,0,code,coding,1,code}' => '410'
fhir.delete('Patient', 'nonexisting')#>>'{issue,0,code,coding,1,code}' => '404'

fhir.read('Patient','myid')#>>'{issue,0,code,coding,1,code}' => '410'

fhir.is_exists('Patient', 'myid') => false
fhir.is_deleted('Patient', 'myid') => true

getv('deleted')#>>'{meta,versionId}' => getv('updated')#>>'{meta,versionId}'

setv('valid-transaction-bundle',
  json_build_object(
    'resourceType', 'Bundle',
    'type', 'transaction',
    'entry', ARRAY[
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Device"}'::json,
        'resource', '{"resourceType": "Device", "manufacturer": "handmade"}'::json
      ),
      json_build_object(
        'transaction', ('{"method": "PUT", "url": "/Flag/' || (getv('flag')->>'id') || '"}')::json,
        'resource', fhirbase_json.assoc(getv('flag'), 'note', '"new-note"'::jsonb)::json
      ),
      json_build_object(
        'transaction', ('{"method": "DELETE", "url": "/Device/' || (getv('device')->>'id') || '"}')::json
      )
    ]::json[]
  )::jsonb
);


setv('valid-trans',
  fhir.transaction(
    getv('valid-transaction-bundle')
  )
);

getv('valid-trans')->>'resourceType' => 'Bundle'

ROLLBACK;
