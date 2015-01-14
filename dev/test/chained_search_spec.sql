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

expect 'find by _id'
   SELECT count(*)
     FROM search(
       'Patient',
       '_id='|| _extract_id(getv('pt')->>'id')
     )
=> 1::bigint

expect
  SELECT string_agg(logical_id::varchar, '|')
    FROM search(
      'Patient',
      'organization._id='|| _extract_id(getv('org')->>'id')
    )
=> _extract_id(getv('pt')->>'id')


expect
   SELECT count(*)
     FROM search('Patient', ('organization._id='|| gen_random_uuid()))
=> 0::bigint

ROLLBACK;
