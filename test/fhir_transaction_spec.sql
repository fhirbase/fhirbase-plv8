-- #import ../src/gen.sql
-- #import ../src/fhir/crud.sql
-- #import ../src/fhir/generate.sql
-- #import ../src/fhir/transaction.sql

BEGIN;
SET search_path TO vars, public;

SELECT generate.generate_tables('{Patient,Alert,Device}');
setv( 'cfg', '{"base":"https://test.me"}');

setv('alert-json','{"resourceType": "Alert", "note": "old-note" }');
setv('device-json', '{"resourceType": "Device", "manufacturer": "Acme" }');

setv('alert',  crud.create(getv('cfg'), getv('alert-json')));
setv('device', crud.create(getv('cfg'), getv('device-json')));

setv('bundle-json',
  json_build_object(
    'resourceType', 'Bundle',
    'entry', ARRAY[
      json_build_object(
        'id', '@create-device',
        'resource', '{ "resourceType": "Device", "manufacturer": "handmade"}'::json
      ),
      json_build_object(
        'id','????',
        'resource', getv('alert')::json
      ),
      json_build_object(
        'id', getv('device')->>'id',
        'deleted', current_timestamp
      )
    ]::json[]
  )::jsonb
);

getv('bundle-json') => '{}'::jsonb

/* '{"resourceType" : "Bundle", "entry" : [ { "id" : "@create-device", */
/* "category" : [], "content" : */
/* { "resourceType": "Device", "manufacturer": "handmade"} }, */
/* { "id" : "{{update-alert}}", "link" : [{ "rel" : "self", "href" : "{{update-vid-alert}}" }], "category" : [], */
/* "content" : { "resourceType": "Alert", "note": "new-note" } },
{ "id" : "{{delete-device}}",
"deleted" : "2012-05-29T23:45:32+00:00" } ] }'::jsonb */


setv('trans',
  transaction.fhir_transaction(
    getv('cfg'),
    gen._tpl(
      getv('bundle-json')::text,
      'update-alert', getv('alert')->>'id',
      'delete-device', getv('device')->>'id',
      'update-vid-alert', crud._extract_vid((getv('alert')#>>'{link,0,href}'))
    )::jsonb
  )
);

expect
  crud.read(
     getv('cfg'), 'Device', getv('trans')#>>'{entry,0,id}'
  )#>>'{manufacturer}'
=> 'handmade'

expect
  crud.read(
     getv('cfg'), 'Alert', getv('trans')#>>'{entry,1,id}'
  )#>>'{note}'
=> 'new-note'

expect
  crud.is_deleted(
     getv('cfg'), 'Device', getv('trans')#>>'{entry,2,id}'
  )
=> true

--TODO: more asserts
ROLLBACK;
