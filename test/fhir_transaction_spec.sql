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

setv('bundle-json',
  '{"resourceType" : "Bundle", "entry" : [ { "id" : "@create-device", "category" : [], "content" : { "resourceType": "Device", "manufacturer": "handmade"} }, { "id" : "{{update-alert}}", "link" : [{ "rel" : "self", "href" : "{{update-vid-alert}}" }], "category" : [], "content" : { "resourceType": "Alert", "note": "new-note" } }, { "id" : "{{delete-device}}", "deleted" : "2012-05-29T23:45:32+00:00" } ] }'::jsonb
);

setv('alert', crud.fhir_create(getv('cfg'), getv('alert-json'))#>'{entry,0}');
setv('device', crud.fhir_create(getv('cfg'), getv('device-json'))#>'{entry,0}');

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
  crud.fhir_read(
     getv('cfg'), 'Device', getv('trans')#>>'{entry,0,id}'
  )#>>'{entry,0,content,manufacturer}'
=> 'handmade'

expect
  crud.fhir_read(
     getv('cfg'), 'Alert', getv('trans')#>>'{entry,1,id}'
  )#>>'{entry,0,content,note}'
=> 'new-note'

expect
  crud.fhir_is_deleted_resource(
     getv('cfg'), 'Device', getv('trans')#>>'{entry,2,id}'
  )
=> true

--TODO: more asserts
ROLLBACK;


