--db:fhirb
--{{{

--  Set of functions for tag operations

-- Return all tags
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', '["todo"]'::json
  )::jsonb
$$ IMMUTABLE;

COMMENT ON FUNCTION fhir_tags(jsonb)
IS 'Return all tags in system';

-- Return all tags for resourceType
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb, _res_type text) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', '["todo"]'::json
  )::jsonb
$$ IMMUTABLE;


-- Return all tags for resource
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb, _res_type text, _id_ uuid) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', coalesce((
      SELECT r.category::json
      FROM resource r
      WHERE r.resource_type = _res_type
      AND r.logical_id = _id_
    ), NULL::json))::jsonb
$$ IMMUTABLE;

-- Return all tags for resource version
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb, _res_type text, _id_ uuid, _vid uuid) RETURNS jsonb
LANGUAGE sql AS $$
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
$$ IMMUTABLE;


-- Affix tag to resource with _id
CREATE OR REPLACE
FUNCTION fhir_affix_tags(_cfg jsonb, _res_type text, _id_ uuid, _tags jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
      UPDATE "{{tbl}}"
      SET category = _merge_tags(category, $2)
      WHERE logical_id = $1
      RETURNING category
    $SQL$, 'tbl', lower(_res_type))
    INTO res USING _id_, _tags;
  RETURN res;
END;
$$;

CREATE OR REPLACE
FUNCTION fhir_affix_tags(_cfg jsonb, _res_type text, _id_ uuid, _vid_ uuid, _tags jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
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
END;
$$;



-- Remove all tag from current version of resource with _id
CREATE OR REPLACE
FUNCTION fhir_remove_tags(_cfg jsonb, _res_type text, _id_ uuid)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
      UPDATE "{{tbl}}"
      SET category = '[]'::jsonb
      WHERE logical_id = $1
    $SQL$, 'tbl', lower(_res_type))
  USING _id_;

  RETURN 1;
END;
$$;

-- Remove all tag from resource with _id and _vid
CREATE OR REPLACE
FUNCTION fhir_remove_tags(_cfg jsonb, _res_type text, _id_ uuid, _vid_ uuid) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
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
END;
$$;
--}}}
