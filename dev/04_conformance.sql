--db:fhirb
--{{{

-- most of params should go from _cfg
-- TODO: check all fields
CREATE OR REPLACE
FUNCTION fhir_conformance(_cfg jsonb) RETURNS jsonb
LANGUAGE sql AS $$
SELECT json_build_object(
  'resourceType', 'Conformance',
  'date', _cfg->'date',
  'name', _cfg->'name',
  'identifier', _cfg->'identifier',
  'publisher', _cfg->'publisher',
  'telecom', _cfg->'telecom',
  'fhirVersion', _cfg->'fhirVersion',
  'acceptUnknown', _cfg->'acceptUnknown',
  'rest', ARRAY[json_build_object(
    'mode', 'server',
    'operation', '[ { "code": "transaction" }, { "code": "history-system" } ]',
    'resource',
      (SELECT json_agg(
          json_build_object(
            'type', e.path[1],
            'profile', json_build_object(
              'reference', _cfg->>'base' || '/Profile/' || e.path[1]
            ),
            'operation', '[{ "code": "read" }, { "code": "vread" }, { "code": "update" }, { "code": "history-instance" }, { "code": "create" }, { "code": "history-type" } ]'::json
          )
        )
        FROM fhir.resource_elements e
       WHERE array_length(path,1) = 1)
  )]
)::jsonb;
$$;

CREATE OR REPLACE
FUNCTION fhir_profile(_cfg jsonb, _resource_name_ text) RETURNS jsonb
LANGUAGE sql AS $$
SELECT null::jsonb
$$;

SELECT fhir_conformance('{"base": "mysrv"}');
--}}}
