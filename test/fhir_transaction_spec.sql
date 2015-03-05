-- #import ../src/gen.sql
-- #import ../src/crud.sql
-- #import ../src/generate.sql
-- #import ../src/transaction.sql

BEGIN;
SET search_path TO vars, public;

SELECT generate.generate_tables('{Patient,Alert,Device}');
setv( 'cfg', '{"base":"https://test.me"}');

setv('alert-json','{"resourceType": "Alert", "note": "old-note" }');
setv('device-json', '{"resourceType": "Device", "manufacturer": "Acme" }');

setv('alert',  crud.create(getv('cfg'), getv('alert-json')));
setv('device', crud.create(getv('cfg'), getv('device-json')));

setv('valid-transaction-bundle',
  json_build_object(
    'resourceType', 'Bundle',
    'entry', ARRAY[
      json_build_object(
        'status', 'create',
        'resource', '{"resourceType": "Device", "manufacturer": "handmade"}'::json
      ),
      json_build_object(
        'status', 'update',
        'resource', jsonbext.assoc(getv('alert'), 'note', '"new-note"'::jsonb)::json
      ),
      json_build_object(
        'status', 'delete',
        'deleted', json_build_object(
          'type', 'Device',
          'resourceId', getv('device')->>'id',
          'versionId', getv('device')#>>'{meta,versionId}',
          'instant', current_timestamp
        )
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
        'status', 'create',
        'resource', '{"resourceType": "Alert", "note": "another alert"}'::json
      ),
      json_build_object(
        'status', 'delete',
        'deleted', json_build_object(
          'type', 'Device',
          'resourceId', 'nonexistentid',
          'instant', current_timestamp
        )
      ),
      json_build_object(
        'status', 'create',
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

--TODO: more asserts
ROLLBACK;
