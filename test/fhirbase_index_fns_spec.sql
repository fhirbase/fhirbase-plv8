-- #import ../src/tests.sql
-- #import ../src/fhirbase_idx_fns.sql

BEGIN;

SET search_path TO fhirbase_idx_fns, vars, public;

_unaccent_string('Jóe Ácme') => 'Joe Acme'

setv('obs',
  '{"resourceType":"Observation","text":{"status":"generated","div":"<div></div>"},"name":{"coding":[{"system":"custom","code":"GLU","display":"Glucose [Mass/volume] in Blood"},{"system":"http://loinc.org","code":"2339-0","display":"Glucose [Mass/volume] in Blood"}]},"valueQuantity":{"value":6.3,"units":"mmol/l","system":"http://unitsofmeasure.org","code":"mmol/l"},"interpretation":{"coding":[{"system":"http://hl7.org/fhir/v2/0078","code":"A","display":"abnormal"}]},"appliesPeriod":{"start":"2013-04-02T09:30:10+01:00","end":"2013-04-05T09:30:10+01:00"},"issued":"2013-04-03T15:30:10+01:00","status":"final","reliability":"ok","bodySite":{"coding":[{"system":"http://snomed.info/sct","code":"308046002","display":"Superficial forearm vein"}]},"method":{"coding":[{"system":"http://snomed.info/sct","code":"120220003","display":"Injection to forearm"}]},"identifier":{"use":"official","system":"http://www.bmc.nl/zorgportal/identifiers/observations","value":"6323"},"subject":{"reference":"Patient/f001","display":"P. van de Heuvel"},"performer":[{"reference":"Practitioner/f005","display":"A. Langeveld"}],"referenceRange":[{"low":{"value":3.1,"units":"mmol/l","system":"http://unitsofmeasure.org","code":"mmol/l"},"high":{"value":6.2,"units":"mmol/l","system":"http://unitsofmeasure.org","code":"mmol/l"}}]}'::jsonb
);

index_primitive_as_token('{"a":[{"b":1},{"b":2}]}','{a,b}') => '{1,2}'::text[]

index_primitive_as_token(getv('obs'),'{status}') => '{final}'::text[]

expect
  index_codeableconcept_as_token(
    getv('obs'), '{name}'
  )
=> '{custom|GLU,http://loinc.org|2339-0,2339-0,GLU}'::text[]

expect
  index_coding_as_token(
    getv('obs'), '{name,coding}'
  )
=> '{custom|GLU,http://loinc.org|2339-0,2339-0,GLU}'::text[]

setv('pt-id',
  '{"resourceType":"Patient","identifier": [{"use": "official", "label": "MRN", "system": "MRN", "value": "7777777" }, { "use": "official", "label": "BSN", "system": "urn:oid:2.16.840.1.113883.2.4.6.3", "value": "123456789" }]}'
);

expect
  index_identifier_as_token(getv('pt-id'),'{identifier}')
=> '{urn:oid:2.16.840.1.113883.2.4.6.3|123456789,MRN|7777777,7777777,123456789}'::text[]

setv('pt-txt',
  '{"resourceType":"Patient","name": [ { "use": "official", "text": "Roel", "family": [ "Bor" ], "given": [ "Roelof Olaf" ], "prefix": [ "Drs." ], "suffix": [ "PDEng." ] } ]}'
);

expect
  index_as_string(getv('pt-txt'),'{name}')::text ilike '%Roel%'
=> true

expect
  index_as_string(getv('pt-txt'),'{name}')::text ilike '%Bor%'
=> true

setv('pt-ref',
  '{"resourceType":"Patient","managingOrganization": { "reference": "Organization/1", "display": "AUMC"}}'
);

expect
  index_as_reference(getv('pt-ref'),'{managingOrganization}'::text[])
=> '{Organization/1,1}'

ROLLBACK;
