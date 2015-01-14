\set pt `cat test/fixtures/pt.json`
\set pt_uuid '550e8400-e29b-41d4-a716-446655440010'
\set pt_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'

\set pt2 `cat test/fixtures/pt2.json`
\set pt2_uuid '550e8400-e29b-41d4-a716-446655440011'
\set pt2_tags  '[{"scheme": "http://pt.com", "term": "http://pt/noise", "label":"noise"}]'

\set doc_ref `cat test/fixtures/documentreference-example.json`
\set doc_ref_uuid '550e8400-e29b-41d4-a716-446655440012'

BEGIN;

truncate  __vars;

setv('cfg','{"base":"https://test.me"}'::jsonb);
setv('orgj', '{"resourceType":"Organization", "name": "Health Level Seven"}'::jsonb);
setv('org',
  fhir_create(getv('cfg'), getv('orgj'))#>'{entry,0}'
);

setv('pt-tpl', '{"resourceType":"Patient", "managingOrganization": { "reference": "%s"}}'::jsonb);


setv('pt',
  fhir_create(
    getv('cfg'),
    format(
      (getv('pt-tpl')::text),
      'Organization/' || _extract_id(getv('org')->>'id')
    )::jsonb
  )#>'{entry,0}'
);

setv('pt-noise',
  fhir_create(
    getv('cfg'),
    format((getv('pt-tpl')::text), 'Organization/other')::jsonb
  )#>'{entry,0}'
);


SELECT * FROM _parse_param('organization=Seven');
SELECT * FROM _expand_search_params('Patient','organization.name=Seven');
SELECT * FROM build_search_query('Patient','organization.name=Seven');

expect 'chained search'
  fhir_search(
    getv('cfg'),'Patient','organization.name=Seven'
  )#>>'{entry,0,id}'
=> (getv('pt')->>'id')

expect 'no false result'
  jsonb_array_length(
    fhir_search(
      getv('cfg'),'Patient','organization.name=Seven'
    )->'entry'
  )
=> 1

ROLLBACK;
