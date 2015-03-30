-- #import ./fhirbase_json.sql
-- #import ./fhirbase_gen.sql
-- #import ./fhirbase_coll.sql
-- #import ./fhirbase_util.sql
-- #import ./fhirbase_generate.sql

func _history_bundle(_cfg_ jsonb, _entries_ jsonb) RETURNS jsonb
  SELECT json_build_object(
    'type', 'history',
    'resourceType', 'Bundle',
    'entry', _entries_
  )::jsonb

func! history(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS jsonb
  WITH entry AS (
    SELECT json_build_object('resource', r.content)::jsonb as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _resource_type_
           AND logical_id = fhirbase_crud._extract_id(_id_)
        UNION ALL
        SELECT * FROM resource_history
         WHERE resource_type = _resource_type_
           AND logical_id = fhirbase_crud._extract_id(_id_)
      ) r ORDER BY r.updated desc
  )
  SELECT this._history_bundle(_cfg_, json_agg(entry)::jsonb)
    FROM entry


func! history(_cfg_ jsonb, _resource_type_ text) RETURNS jsonb
  WITH entry AS (
    SELECT json_build_object('resource', r.content)::jsonb as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _resource_type_
        UNION ALL
        SELECT * FROM resource_history
         WHERE resource_type = _resource_type_
      ) r ORDER BY r.updated desc
  )
  SELECT this._history_bundle(_cfg_, json_agg(entry)::jsonb)
    FROM entry

func! history(_cfg_ jsonb) RETURNS jsonb
  WITH entry AS (
    SELECT json_build_object('resource', r.content)::jsonb as entry
      FROM (
        SELECT * FROM resource
        UNION ALL
        SELECT * FROM resource_history
      ) r ORDER BY r.updated desc
  )
  SELECT this._history_bundle(_cfg_, json_agg(entry)::jsonb)
    FROM entry
