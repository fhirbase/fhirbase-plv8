BEGIN;

setv('cfg', '{"base":"https://test.me"}'::jsonb);
setv('device', '{"resourceType": "Device", "model": "Jóe", "manufacturer": "Acme" }');

_unaccent_string('Jóe Ácme') => 'Joe Acme'

setv('dev',
  fhir_create(getv('cfg'), 'Device', getv('device'), null)
);

fhir_search(getv('cfg'), 'Device', 'model=Joe')#>>'{entry,0,content,resourceType}' => 'Device'
fhir_search(getv('cfg'), 'Device', 'manufacturer=Ácme')#>>'{entry,0,content,resourceType}' => 'Device'
fhir_search(getv('cfg'), 'Device', 'model=Jóe')#>>'{entry,0,content,resourceType}' => 'Device'

ROLLBACK;
--}}}
