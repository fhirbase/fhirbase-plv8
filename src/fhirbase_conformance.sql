-- most of params should go from _cfg
-- TODO: check all fields
func conformance(_cfg jsonb) RETURNS jsonb
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
        COALESCE((SELECT json_agg(
            json_build_object(
              'type', r.logical_id,
              'profile', json_build_object(
                'reference', _cfg->>'base' || '/Profile/' || r.logical_id
              ),
              'readHistory', true,
              'updateCreate', true,
              'operation', ARRAY['{ "code": "read" }'::json, '{ "code": "vread" }'::json, '{ "code": "update" }'::json, '{ "code": "history-instance" }'::json, '{ "code": "create" }'::json, '{ "code": "history-type" }'::json],
              'searchParam',  (
                SELECT  array_agg(sp.content)  FROM searchparameter sp
                WHERE sp.base = r.logical_id
              )
            )
          )
          FROM structuredefinition r
          WHERE r.installed = true
        ), '[]'::json)
    )]
  )::jsonb


func structuredefinition(_cfg jsonb, _resource_name_ text) RETURNS jsonb
  select  content
    from structuredefinition
    where lower(logical_id) = lower(_resource_name_)
