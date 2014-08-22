--db:fhirb
--{{{

-- most of params should go from _cfg
-- TODO: check all fields
CREATE OR REPLACE
FUNCTION fhir_conformance(_cfg jsonb) RETURNS jsonb
LANGUAGE sql AS $$
SELECT json_build_object(
  'resourceType', 'Conformance',
  'identifier', _cfg->'identifier',
  'version', _cfg->'version',
  'name', _cfg->'name',
  'publisher', _cfg->'publisher',
  'telecom', _cfg->'telecom',
  'description', _cfg->'description',
  'status', 'active',
  'date', _cfg->'date',
  'software', _cfg->'software',
  'fhirVersion', _cfg->'fhirVersion',
  'acceptUnknown', _cfg->'acceptUnknown',
  'format', _cfg->'format',
  'rest', ARRAY[json_build_object(
    'mode', 'server',
    'operation', ARRAY['{ "code": "transaction" }'::json, '{ "code": "history-system" }'::json],
    'cors', _cfg->'cors',
    'resource',
      (SELECT json_agg(
          json_build_object(
            'type', e.path[1],
            'profile', json_build_object(
              'reference', _cfg->>'base' || '/Profile/' || e.path[1]
            ),
            'readHistory', true,
            'updateCreate', true,
            'operation', ARRAY['{ "code": "read" }'::json, '{ "code": "vread" }'::json, '{ "code": "update" }'::json, '{ "code": "history-instance" }'::json, '{ "code": "create" }'::json, '{ "code": "history-type" }'::json],
            'searchParam',  (
              SELECT  json_agg(t.*)  FROM (
                SELECT sp.name, sp.type, sp.documentation
                FROM fhir.resource_search_params sp
                  WHERE sp.path[1] = e.path[1]
              ) t
            )

          )
        )
        FROM fhir.resource_elements e
        WHERE array_length(path,1) = 1
      )
  )]
)::jsonb;
$$;


CREATE OR REPLACE
FUNCTION fhir_profile(_cfg jsonb, _resource_name_ text) RETURNS jsonb
LANGUAGE sql AS $$
WITH elems AS (
  SELECT array_to_string(e.path,'.') as path,
         json_build_object(
           'min', e.min,
           'max', e.max,
           'type', COALESCE((SELECT json_agg(tt.*) FROM (SELECT t as code FROM unnest(e.type) t) tt), '[]'::json)
         ) as definition
    FROM fhir.resource_elements e
   WHERE path[1]=_resource_name_
), params AS (
  SELECT sp.name, sp.type, sp.documentation, array_to_string(sp.path, '/') as xpath
  FROM fhir.resource_search_params sp
    WHERE sp.path[1] = _resource_name_
)
SELECT json_build_object(
   'name', _resource_name_,
   'resourceType', 'Profile',
   'structure', ARRAY[json_build_object(
     'type', _resource_name_,
     'publish', true,
     'differential', json_build_object(
       'element', (SELECT json_agg(t.*) FROM elems  t)
     ),
     'searchParam',  (SELECT  json_agg(t.*)  FROM params t)
   )]
)::jsonb
$$;

SELECT fhir_profile('{}', 'Patient');
--}}}
