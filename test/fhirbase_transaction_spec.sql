-- #import ../src/fhirbase_gen.sql
-- #import ../src/fhirbase_crud.sql
-- #import ../src/fhirbase_generate.sql
-- #import ../src/fhirbase_transaction.sql

expect
  fhirbase_transaction._url_to_crud_action('/Device'::text, 'POST'::text)
=> ARRAY['create', 'Device']::text[]

expect
  fhirbase_transaction._url_to_crud_action('/Patient/patient-id'::text, 'PUT'::text)
=> ARRAY['update', 'Patient', 'patient-id']::text[]

expect
  fhirbase_transaction._url_to_crud_action('/Patient/patient-id'::text, 'DELETE'::text)
=> ARRAY['delete', 'Patient', 'patient-id']::text[]

expect
  fhirbase_transaction._url_to_crud_action('/Patient'::text, 'GET'::text)
=> ARRAY['search', 'Patient']::text[]

expect
  fhirbase_transaction._url_to_crud_action('/Patient/pid/_history/vid'::text, 'GET'::text)
=> ARRAY['vread', 'Patient', 'pid', 'vid']::text[]

expect
  fhirbase_transaction._url_to_crud_action('/Patient/pid'::text, 'GET'::text)
=> ARRAY['read', 'Patient', 'pid']::text[]

expect
  fhirbase_transaction._url_to_crud_action('/Patient/_search'::text, 'POST'::text)
=> ARRAY['search', 'Patient']::text[]

expect_raise 'Wrong URL'
  SELECT fhirbase_transaction._url_to_crud_action('/Patient'::text, 'PUT'::text);

expect_raise 'Wrong URL'
  SELECT fhirbase_transaction._url_to_crud_action(''::text, 'POST'::text);

expect_raise 'Wrong URL'
  SELECT fhirbase_transaction._url_to_crud_action('/Patient/foobar/asd'::text, 'POST'::text);

------------------------------------------------------------

BEGIN;
SET search_path TO vars, public;

SELECT fhirbase_generate.generate_tables('{Patient,Flag,Device}');
setv('cfg', '{"base":"https://test.me"}');

setv('flag-json','{"resourceType": "Flag", "note": "old-note" }');
setv('device-json', '{"resourceType": "Device", "manufacturer": "Acme" }');

setv('flag',  fhirbase_crud.create(getv('cfg'), getv('flag-json')));
setv('device', fhirbase_crud.create(getv('cfg'), getv('device-json')));

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
  fhirbase_transaction.transaction(
    getv('cfg'),
    getv('valid-transaction-bundle')
  )
);

getv('valid-trans')->>'type' => 'transaction-response'

--select tests._debug(fhirbase_json.jsonb_to_array(getv('valid-transaction-bundle')->'entry'));

expect
  jsonb_array_length(
    getv('valid-trans')->'entry'
  )
=> 3

expect
  fhirbase_crud.read(
     getv('cfg'), getv('valid-trans')#>>'{entry,0,resource,id}'
  )#>>'{manufacturer}'
=> 'handmade'

expect
  fhirbase_crud.read(
     getv('cfg'), getv('valid-trans')#>>'{entry,1,resource,id}'
  )#>>'{note}'
=> 'new-note'

expect
  fhirbase_crud.is_deleted(
    getv('cfg'),
    'Device',
    getv('valid-trans')#>>'{entry,2,resource,id}'
  )
=> true

-----------------------------------------------------------------

SELECT COUNT(*)::integer FROM flag => 1::integer

setv('invalid-transaction-bundle',
  json_build_object(
    'resourceType', 'Bundle',
    'entry', ARRAY[
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Flag"}'::json,
        'resource', '{"resourceType": "Flag", "note": "another flag"}'::json
      ),
      json_build_object(
        'transaction', ('{"method": "DELETE", "url": "/Device/nonexistentid"}')::json
      ),
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Flag"}'::json,
        'resource', '{"resourceType": "Flag", "note": "another flag 2"}'::json
      )
    ]::json[]
  )::jsonb
);


--expect 'outcome'
--  fhirbase_transaction.transaction(getv('cfg'), getv('invalid-transaction-bundle'))->>'resourceType'
--=> 'OperationOutcome'

--expect
--  SELECT COUNT(*)::integer FROM flag
--=> 1::integer

------------------------------------------------------------

setv('crossreferenced-transaction-bundle',
  json_build_object(
    'resourceType', 'Bundle',
    'type', 'transaction',
    'base', getv('cfg')->>'base',
    'entry', ARRAY[
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Device"}'::json,
        'base', 'urn:uuid:',
        'resource', '{"resourceType": "Device", "patient": {"reference": "0B3538BD-C3FC-414E-BF7E-248A23A58EC5"}}'::json
      ),
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Patient"}'::json,
        'base', 'urn:uuid:',
        'resource', '{"resourceType":"Patient", "name":{"text":"Goga"}, "id": "0B3538BD-C3FC-414E-BF7E-248A23A58EC5"}'::json
      )
    ]::json[]
  )::jsonb
);

setv('crossreferenced-transaction-response',
  fhirbase_transaction.transaction(
    getv('cfg'),
    getv('crossreferenced-transaction-bundle')
  )
);

expect
  getv('crossreferenced-transaction-response')#>>'{entry,0,resource,patient,reference}'
=> ('Patient/' || (getv('crossreferenced-transaction-response')#>>'{entry,1,resource,id}'))

expect
  fhirbase_crud.read(
    getv('cfg'),
    getv('crossreferenced-transaction-response')#>>'{entry,0,resource,id}'
  )#>>'{patient,reference}'
=> ('Patient/' || (getv('crossreferenced-transaction-response')#>>'{entry,1,resource,id}'))

------------------------------------------------------------

setv('crossreferenced-with-update-transaction-bundle',
  json_build_object(
    'resourceType', 'Bundle',
    'type', 'transaction',
    'base', getv('cfg')->>'base',
    'entry', ARRAY[
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Patient"}'::json,
        'base', 'urn:uuid:',
        'resource', '{"resourceType":"Patient", "name":{"text":"Archibald"}, "id": "archi"}'::json
      ),
      json_build_object(
        'transaction',
        ('{"method": "PUT", "url": "/Device/' || (getv('crossreferenced-transaction-response')#>>'{entry,0,resource,id}') || '"}')::json,
        'base', 'urn:uuid:',
        'resource', fhirbase_json.merge(
          (getv('crossreferenced-transaction-response')#>'{entry,0,resource}'),
          '{"patient": {"reference": "archi"}}'
        )
      )
    ]::json[]
  )::jsonb
);

setv('crossreferenced-with-update-transaction-response',
  fhirbase_transaction.transaction(
    getv('cfg'),
    getv('crossreferenced-with-update-transaction-bundle')
  )
);

expect
  getv('crossreferenced-with-update-transaction-response')#>>'{entry,1,resource,patient,reference}'
=> ('Patient/' || (getv('crossreferenced-with-update-transaction-response')#>>'{entry,0,resource,id}'))

ROLLBACK;
