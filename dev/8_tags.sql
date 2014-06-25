--db:fhirb
--{{{

--  Set of functions for tag operations

-- Return all tags
CREATE OR REPLACE FUNCTION
tags()
RETURNS jsonb LANGUAGE sql AS $$
SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), '[]'::json))::jsonb
  FROM (
    SELECT scheme, term, label
    FROM tag
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

-- Return all tags for resourceType
CREATE OR REPLACE FUNCTION
tags(_res_type varchar) -- return all tags
RETURNS jsonb LANGUAGE sql AS $$
  SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), '[]'::json))::jsonb
  FROM (
    SELECT scheme, term, label
    FROM tag
    WHERE resource_type = _res_type
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

-- Return all tags for resource
CREATE OR REPLACE FUNCTION
tags(_res_type varchar, _id uuid) -- return all tags
RETURNS jsonb LANGUAGE sql AS $$
  SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), '[]'::json))::jsonb
  FROM (
    SELECT scheme, term, label
    FROM tag
    WHERE resource_type = _res_type
    AND resource_id = _id
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

-- Return all tags for resource version
CREATE OR REPLACE FUNCTION
tags(_res_type varchar, _id uuid, _vid uuid)
RETURNS jsonb LANGUAGE sql AS $$
  SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), '[]'::json))::jsonb
  FROM (
    SELECT scheme, term, label
    FROM history_tag
    WHERE resource_type = _res_type
    AND resource_id = _id
    AND resource_version_id = _vid
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

-- Affix tag to resource with _id
DROP FUNCTION IF EXISTS affix_tags(_res_type varchar, _id uuid, _tags jsonb);
CREATE OR REPLACE FUNCTION
affix_tags(_res_type varchar, _id uuid, _tags jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    eval_template($SQL$
      WITH rsrs AS (
        SELECT logical_id, version_id
        FROM  "{{tbl}}"
        WHERE logical_id = $1
      ),
      old_tags AS (
        SELECT scheme, term, label FROM {{tbl}}_tag
        WHERE resource_id = $1
      ),
      new_tags AS (
        SELECT x->>'scheme' as scheme,
               x->>'term' as term,
               x->>'label' as label
        FROM jsonb_array_elements($2) x
        EXCEPT
        SELECT * from old_tags
      ),
      inserted AS (
        INSERT INTO "{{tbl}}_tag"
        (resource_id, resource_version_id, scheme, term, label)
        SELECT rsrs.logical_id,
               rsrs.version_id,
               new_tags.scheme,
               new_tags.term,
               new_tags.label
          FROM new_tags, rsrs
        RETURNING scheme, term, label)
      SELECT coalesce(json_agg(row_to_json(inserted)), '[]'::json)::jsonb
        FROM inserted
      $SQL$, 'tbl', lower(_res_type))
    INTO res USING _id, _tags;
    RETURN res;
END;
$$;

-- Affix tag to resource with _id and _vid
DROP FUNCTION IF EXISTS affix_tags(_res_type varchar, _id uuid, _vid uuid, _tags jsonb);
CREATE OR REPLACE FUNCTION
affix_tags(_res_type varchar, _id uuid, _vid uuid, _tags jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    eval_template($SQL$
      WITH rsrs AS (
        SELECT logical_id,
               version_id
        FROM  "{{tbl}}_history"
        WHERE version_id = $1
      ),
      old_tags AS (
        SELECT scheme, term, label FROM {{tbl}}_history_tag
        WHERE resource_version_id = $1
      ),
      new_tags AS (
        SELECT x->>'scheme' as scheme,
               x->>'term' as term,
               x->>'label' as label
        FROM jsonb_array_elements($2) x
        EXCEPT
        SELECT * from old_tags
      ),
      inserted AS (
        INSERT INTO "{{tbl}}_history_tag"
        (resource_id, resource_version_id, scheme, term, label)
        SELECT rsrs.logical_id,
               rsrs.version_id,
               new_tags.scheme,
               new_tags.term,
               new_tags.label
          FROM new_tags, rsrs
        RETURNING scheme, term, label)
      SELECT coalesce(json_agg(row_to_json(inserted)), '[]'::json)::jsonb
        FROM inserted
      $SQL$, 'tbl', lower(_res_type))
    INTO res USING _vid, _tags;
    RETURN res;
END;
$$;

-- Remove all tag from current version of resource with _id
DROP FUNCTION IF EXISTS remove_tags(_res_type varchar, _id uuid);
CREATE OR REPLACE FUNCTION
remove_tags(_res_type varchar, _id uuid)
RETURNS bigint LANGUAGE sql AS $$
  WITH DELETED AS (
  DELETE FROM tag
    WHERE resource_type = _res_type
    AND resource_id = _id RETURNING * )
  SELECT count(*) FROM DELETED;
$$;

-- Remove all tag from resource with _id and _vid
DROP FUNCTION IF EXISTS remove_tags(_res_type varchar, _id uuid, _vid uuid);
CREATE OR REPLACE FUNCTION
remove_tags(_res_type varchar, _id uuid, _vid uuid)
RETURNS bigint LANGUAGE sql AS $$
  WITH DELETED AS (
  DELETE FROM history_tag
    WHERE resource_type = _res_type
    AND resource_id = _id
    AND resource_version_id = _vid RETURNING *)
  SELECT count(*) FROM DELETED;
$$;
--}}}
