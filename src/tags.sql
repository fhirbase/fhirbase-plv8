-- #import ./gen.sql
-- #import ./generate.sql

func! fhir_tags(_cfg jsonb) RETURNS jsonb
  --IS 'Return all tags in system';
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', '["todo"]'::json
  )::jsonb

func! fhir_tags(_cfg jsonb, _res_type text) RETURNS jsonb
  -- Return all tags for resourceType
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', '["todo"]'::json
  )::jsonb


func! fhir_tags(_cfg jsonb, _res_type text, _id_ text) RETURNS jsonb
  -- Return all tags for resource
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', coalesce((
      SELECT r.category::json
      FROM resource r
      WHERE r.resource_type = _res_type
      AND r.logical_id = _id_
    ), NULL::json))::jsonb

func! fhir_tags(_cfg jsonb, _res_type text, _id_ text, _vid text) RETURNS jsonb
  -- Return all tags for resource version
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(
     (
         SELECT category::json FROM (
          SELECT r.category FROM resource r
           WHERE r.resource_type = _res_type
             AND r.logical_id = _id_ AND r.version_id = _vid
          UNION
          SELECT r.category FROM resource_history r
           WHERE r.resource_type = _res_type
             AND r.logical_id = _id_ AND r.version_id = _vid
        ) x LIMIT 1
    ),
    NULL::json))::jsonb


proc! fhir_affix_tags(_cfg jsonb, _res_type text, _id_ text, _tags jsonb) RETURNS jsonb
  -- Affix tag to resource with _id
  res jsonb;
  BEGIN
    EXECUTE
      gen._tpl($SQL$
        UPDATE "{{tbl}}"
        SET category = _merge_tags(category, $2)
        WHERE logical_id = $1
        RETURNING category
      $SQL$, 'tbl', lower(_res_type))
      INTO res USING _id_, _tags;
    RETURN res;

proc! fhir_affix_tags(_cfg jsonb, _res_type text, _id_ text, _vid_ text, _tags jsonb) RETURNS jsonb
  res jsonb;
  BEGIN
    EXECUTE
      gen._tpl($SQL$
        WITH res AS (
          UPDATE "{{tbl}}"
          SET category = _merge_tags(category, $2)
          WHERE logical_id = $1 AND version_id = $3
          RETURNING category
        ), his AS (
          UPDATE "{{tbl}}_history"
          SET category = _merge_tags(category, $2)
          WHERE logical_id = $1 AND version_id = $3
          RETURNING category
        )
        SELECT * FROM res
        UNION
        SELECT * FROM his
      $SQL$, 'tbl', lower(_res_type))
      INTO res USING _id_, _tags, _vid_;
    RETURN res;


proc! fhir_remove_tags(_cfg jsonb, _res_type text, _id_ text) RETURNS bigint
  -- Remove all tag from current version of resource with _id
  res jsonb;
  BEGIN
    EXECUTE
      gen._tpl($SQL$
        UPDATE "{{tbl}}"
        SET category = '[]'::jsonb
        WHERE logical_id = $1
      $SQL$, 'tbl', lower(_res_type))
    USING _id_;

    RETURN 1;

-- Remove all tag from resource with _id and _vid
proc! fhir_remove_tags(_cfg jsonb, _res_type text, _id_ text, _vid_ text) RETURNS bigint
  res jsonb;
  BEGIN
    EXECUTE
      gen._tpl($SQL$
        WITH res AS (
          UPDATE "{{tbl}}"
          SET category = '[]'::jsonb
          WHERE logical_id = $1 AND version_id = $2
          RETURNING 1
        ), his AS (
          UPDATE "{{tbl}}_history"
          SET category = '[]'::jsonb
          WHERE logical_id = $1 AND version_id = $2
          RETURNING 1
        )
        SELECT * FROM res, his
      $SQL$, 'tbl', lower(_res_type))
      USING _id_, _vid_;
    RETURN 1;
