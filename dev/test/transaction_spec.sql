BEGIN;
setv( 'cfg', '{"base":"https://test.me"}');

\set alert `cat test/fixtures/alert.json`

setv('alert-json','{"resourceType": "Alert", "note": "old-note" }');
setv('device-json', '{"resourceType": "Device", "manufacturer": "Acme" }');

setv('bundle-json',
  $$ {
    "resourceType" : "Bundle",
    "entry" : [
      {
        "id" : "@create-device",
        "category" : [],
        "content" : { "resourceType": "Device", "manufacturer": "handmade"}
      },
      {
        "id" : "{{update-alert}}",
        "link" : [{ "rel" : "self", "href" : "{{update-vid-alert}}" }],
        "category" : [],
        "content" : { "resourceType": "Alert", "note": "new-note" }
      },
      {
       "id" : "{{delete-device}}",
       "deleted" : "2012-05-29T23:45:32+00:00"
      }
    ]
  }
  $$::jsonb);

setv('alert', fhir_create(getv('cfg'), getv('alert-json'))#>'{entry,0}');
setv('device', fhir_create(getv('cfg'), getv('device-json'))#>'{entry,0}');

setv('trans',
  fhir_transaction(
    getv('cfg'),
    _tpl(
      getv('bundle-json')::text,
      'update-alert', getv('alert')->>'id',
      'delete-device', getv('device')->>'id',
      'update-vid-alert', _extract_vid(getv('alert')#>>'{link,0,href}')
    )::jsonb
  )
);

expect
  fhir_read(
     getv('cfg'), 'Device', getv('trans')#>>'{entry,0,id}'
  )#>>'{entry,0,content,manufacturer}'
=> 'handmade'

expect
  fhir_read(
     getv('cfg'), 'Alert', getv('trans')#>>'{entry,1,id}'
  )#>>'{entry,0,content,note}'
=> 'new-note'

expect
  fhir_is_deleted_resource(
     getv('cfg'), 'Device', getv('trans')#>>'{entry,2,id}'
  )
=> true

--TODO: more asserts
ROLLBACK;

