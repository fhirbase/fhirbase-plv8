\set cfg '{"base":"https://test.me"}'
\set pt `cat test/fixtures/pt.json`
\set pt2 `cat test/fixtures/pt2.json`
\set pt_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'
\set alert `cat test/fixtures/alert.json`


BEGIN;

setv('cfg', '{"base":"https://test.me"}'::jsonb);

setv('pt', :'pt'::jsonb);
setv('pt2', :'pt2'::jsonb);

setv('ipt',
  fhir_create(getv('cfg'), 'Patient', getv('pt'), null)#>'{entry,0}'
);

setv('noise-pt',
  fhir_create(getv('cfg'), 'Patient', getv('pt2'), null)
);

setv('rpt',
  fhir_read(getv('cfg'), 'Patient', (getv('ipt'))#>>'{id}')#>'{entry,0}'
);

SELECT getv('rpt')#>>'{content,name,0,text}' => 'Roel'
SELECT getv('rpt')#>>'{id}' => getv('ipt')#>>'{id}'

expect 'id is built right'
  SELECT _build_id(getv('cfg'), 'Patient', _extract_id((getv('rpt')#>>'{id}'))::uuid)
=> getv('ipt')#>>'{id}'

setv('vrpt',
  fhir_vread(
    getv('cfg'), 'Patient', getv('ipt')#>>'{link,0,href}'
  )#>'{entry,0}'
);

expect 'vread'
 SELECT getv('vrpt')#>>'{content,name,0,text}'
=> 'Roel'

setv('upt',
  fhir_update(
      getv('cfg'), 'Patient',
      (getv('ipt'))#>>'{id}',
      (getv('ipt'))#>>'{link,0,href}',
      getv('pt'),
      null
  )#>'{entry,0}'
);

expect_raise 'Wrong version_id'
  SELECT fhir_update(
      getv('cfg'), 'Patient',
      (getv('ipt'))#>>'{id}',
      (getv('ipt'))#>>'{link,0,href}',
      getv('pt'),
      null
  );


setv('uvrpt',
  fhir_vread(
    getv('cfg'), 'Patient', getv('upt')#>>'{link,0,href}'
  )#>'{entry,0}'
);

expect 'update vread'
 SELECT getv('uvrpt')#>>'{content,name,0,text}'
=> 'Roel'

expect 'version id changed'
 SELECT getv('uvrpt')#>>'{link,0,href}' = getv('vrpt')#>>'{link,0,href}'
=> false

expect 'searchable'
  jsonb_array_length(
    fhir_search(getv('cfg'), 'Patient', 'name=roel')#>'{entry}'
  )
=> 1

expect 'ensure before deleted'
  jsonb_typeof(
    fhir_read(
      getv('cfg'), 'Patient', getv('ipt')#>>'{id}'
    )#>'{entry,0, id}'
  )
=> 'string'

SELECT fhir_delete(
  getv('cfg'), 'Patient', getv('ipt')#>>'{id}'
);

expect 'deleted'
  jsonb_typeof(
    fhir_read(
      getv('cfg'), 'Patient', getv('ipt')#>>'{id}'
    )#>'{entry,0, id}'
  )
=> NULL

setv('hpt',
  fhir_history(
    getv('cfg'),
    'Patient',
    getv('ipt')#>>'{id}',
    '{}'::jsonb
  )
);

expect 'history'
  jsonb_array_length(
    (getv('hpt')->'entry')
  )
=> 2

ROLLBACK;
