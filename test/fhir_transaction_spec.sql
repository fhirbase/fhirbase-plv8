-- #import ../src/gen.sql
-- #import ../src/crud.sql
-- #import ../src/generate.sql
-- #import ../src/transaction.sql

expect
  transaction._url_to_crud_action('/Device'::text, 'POST'::text)
=> ARRAY['create', 'Device']::text[]

expect
  transaction._url_to_crud_action('/Patient/patient-id'::text, 'PUT'::text)
=> ARRAY['update', 'Patient', 'patient-id']::text[]

expect
  transaction._url_to_crud_action('/Patient/patient-id'::text, 'DELETE'::text)
=> ARRAY['delete', 'Patient', 'patient-id']::text[]

expect
  transaction._url_to_crud_action('/Patient'::text, 'GET'::text)
=> ARRAY['search', 'Patient']::text[]

expect
  transaction._url_to_crud_action('/Patient/pid/_history/vid'::text, 'GET'::text)
=> ARRAY['vread', 'Patient', 'pid', 'vid']::text[]

expect
  transaction._url_to_crud_action('/Patient/pid'::text, 'GET'::text)
=> ARRAY['read', 'Patient', 'pid']::text[]

expect
  transaction._url_to_crud_action('/Patient/_search'::text, 'POST'::text)
=> ARRAY['search', 'Patient']::text[]

expect_raise 'Wrong URL'
  SELECT transaction._url_to_crud_action('/Patient'::text, 'PUT'::text);

expect_raise 'Wrong URL'
  SELECT transaction._url_to_crud_action(''::text, 'POST'::text);

expect_raise 'Wrong URL'
  SELECT transaction._url_to_crud_action('/Patient/foobar/asd'::text, 'POST'::text);

------------------------------------------------------------

BEGIN;
SET search_path TO vars, public;

SELECT generate.generate_tables('{Patient,Alert,Device}');
setv('cfg', '{"base":"https://test.me"}');

setv('alert-json','{"resourceType": "Alert", "note": "old-note" }');
setv('device-json', '{"resourceType": "Device", "manufacturer": "Acme" }');

setv('alert',  crud.create(getv('cfg'), getv('alert-json')));
setv('device', crud.create(getv('cfg'), getv('device-json')));

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
        'transaction', ('{"method": "PUT", "url": "/Alert/' || (getv('alert')->>'id') || '"}')::json,
        'resource', jsonbext.assoc(getv('alert'), 'note', '"new-note"'::jsonb)::json
      ),
      json_build_object(
        'transaction', ('{"method": "DELETE", "url": "/Device/' || (getv('device')->>'id') || '"}')::json
      )
    ]::json[]
  )::jsonb
);


setv('valid-trans',
  transaction.transaction(
    getv('cfg'),
    getv('valid-transaction-bundle')
  )
);

getv('valid-trans')->>'type' => 'transaction-response'

--select tests._debug(jsonbext.jsonb_to_array(getv('valid-transaction-bundle')->'entry'));

expect
  jsonb_array_length(
    getv('valid-trans')->'entry'
  )
=> 3

expect
  crud.read(
     getv('cfg'), getv('valid-trans')#>>'{entry,0,resource,id}'
  )#>>'{manufacturer}'
=> 'handmade'

expect
  crud.read(
     getv('cfg'), getv('valid-trans')#>>'{entry,1,resource,id}'
  )#>>'{note}'
=> 'new-note'

expect
  crud.is_deleted(
    getv('cfg'),
    'Device',
    getv('valid-trans')#>>'{entry,2,resource,id}'
  )
=> true

-----------------------------------------------------------------

SELECT COUNT(*)::integer FROM ALERT => 1::integer

setv('invalid-transaction-bundle',
  json_build_object(
    'resourceType', 'Bundle',
    'entry', ARRAY[
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Alert"}'::json,
        'resource', '{"resourceType": "Alert", "note": "another alert"}'::json
      ),
      json_build_object(
        'transaction', ('{"method": "DELETE", "url": "/Device/nonexistentid"}')::json
      ),
      json_build_object(
        'transaction', '{"method": "POST", "url": "/Alert"}'::json,
        'resource', '{"resourceType": "Alert", "note": "another alert 2"}'::json
      )
    ]::json[]
  )::jsonb
);

expect_raise 'resource with id="nonexistentids" does not exist'
  SELECT transaction.transaction(
    getv('cfg'),
    getv('invalid-transaction-bundle')
  );

expect
  SELECT COUNT(*)::integer FROM alert
=> 1::integer

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
  transaction.transaction(
    getv('cfg'),
    getv('crossreferenced-transaction-bundle')
  )
);

expect
  getv('crossreferenced-transaction-response')#>>'{entry,0,resource,patient,reference}'
=> ('Patient/' || (getv('crossreferenced-transaction-response')#>>'{entry,1,resource,id}'))

expect
  crud.read(
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
        'resource', jsonbext.merge(
          (getv('crossreferenced-transaction-response')#>'{entry,0,resource}'),
          '{"patient": {"reference": "archi"}}'
        )
      )
    ]::json[]
  )::jsonb
);

setv('crossreferenced-with-update-transaction-response',
  transaction.transaction(
    getv('cfg'),
    getv('crossreferenced-with-update-transaction-bundle')
  )
);

expect
  getv('crossreferenced-with-update-transaction-response')#>>'{entry,1,resource,patient,reference}'
=> ('Patient/' || (getv('crossreferenced-with-update-transaction-response')#>>'{entry,0,resource,id}'))

ROLLBACK;
