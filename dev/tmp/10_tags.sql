--db:fhirb
--{{{

--  Set of functions for tag operations

-- Return all tags
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb) RETURNS jsonb
LANGUAGE sql AS $$
SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), NULL::json))::jsonb
  FROM (
    SELECT scheme, term, label
    FROM tag
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

COMMENT ON FUNCTION fhir_tags(jsonb)
IS 'Return all tags in system';

-- Return all tags for resourceType
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb, _res_type varchar) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), NULL::json))::jsonb
  FROM (
    SELECT scheme, term, label
    FROM tag
    WHERE resource_type = _res_type
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;
COMMENT ON FUNCTION fhir_tags(jsonb, varchar)
IS 'Return tags for resources with type = _type_';

-- Return all tags for resource
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb, _res_type varchar, _id_ uuid) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), NULL::json))::jsonb
  FROM (
    SELECT t.scheme, t.term, t.label
    FROM tag t
    WHERE t.resource_type = _res_type
    AND t.resource_id = _id_
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

-- Return all tags for resource version
CREATE OR REPLACE
FUNCTION fhir_tags(_cfg jsonb, _res_type varchar, _id_ uuid, _vid uuid) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT
  json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(json_agg(row_to_json(tgs)), NULL::json))::jsonb
  FROM (
    SELECT t.scheme, t.term, t.label
    FROM tag_history t
    WHERE t.resource_type = _res_type
    AND t.resource_id = _id_
    AND t.resource_version_id = _vid
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

-- Affix tag to resource with _id
DROP FUNCTION IF EXISTS fhir_affix_tags(_cfg jsonb, _res_type varchar, _id_ uuid, _tags jsonb);
CREATE OR REPLACE
FUNCTION fhir_affix_tags(_cfg jsonb, _res_type varchar, _id_ uuid, _tags jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
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
    INTO res USING _id_, _tags;

    UPDATE resource SET category = (SELECT json_agg(x)::jsonb FROM (SELECT t.term, t.scheme, t.label FROM tag t WHERE  t.resource_id = _id_) x)
     WHERE resource_type = _res_type
      AND logical_id = _id_;
    RETURN res;
END;
$$;

-- Affix tag to resource with _id and _vid
DROP FUNCTION IF EXISTS fhir_affix_tags(_cfg jsonb, _res_type varchar, _id_ uuid, _vid_ uuid, _tags jsonb);
CREATE OR REPLACE
FUNCTION fhir_affix_tags(_cfg jsonb, _res_type varchar, _id_ uuid, _vid_ uuid, _tags jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
      WITH rsrs AS (
        SELECT logical_id,
               version_id
        FROM  "{{tbl}}_history"
        WHERE version_id = $1
      ),
      old_tags AS (
        SELECT scheme, term, label FROM {{tbl}}_tag_history
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
        INSERT INTO "{{tbl}}_tag_history"
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
    INTO res USING _vid_, _tags;

    UPDATE resource_history SET category = (SELECT json_agg(x)::jsonb FROM (SELECT t.term, t.scheme, t.label FROM tag_history t WHERE  t.resource_version_id = _vid_) x)
     WHERE resource_type = _res_type
      AND version_id = _vid_;
    RETURN res;
END;
$$;

-- Remove all tag from current version of resource with _id
DROP FUNCTION IF EXISTS fhir_remove_tags(_cfg jsonb, _res_type varchar, _id_ uuid);
CREATE OR REPLACE
FUNCTION fhir_remove_tags(_cfg jsonb, _res_type varchar, _id_ uuid) RETURNS bigint
LANGUAGE sql AS $$
  UPDATE resource SET category = NULL
  WHERE resource_type = _res_type
    AND logical_id = _id_;

  WITH DELETED AS (
  DELETE FROM tag t
    WHERE t.resource_type = _res_type
    AND t.resource_id = _id_ RETURNING * )
  SELECT count(*) FROM DELETED;
$$;

-- Remove all tag from resource with _id and _vid
DROP FUNCTION IF EXISTS fhir_remove_tags(_cfg jsonb, _res_type varchar, _id_ uuid, _vid uuid);
CREATE OR REPLACE
FUNCTION fhir_remove_tags(_cfg jsonb, _res_type varchar, _id_ uuid, _vid uuid) RETURNS bigint
LANGUAGE sql AS $$
  UPDATE resource_history SET category = NULL
  WHERE resource_type = _res_type
    AND logical_id = _id_;

  WITH DELETED AS (
  DELETE FROM tag_history ht
    WHERE ht.resource_type = _res_type
    AND ht.resource_id = _id_
    AND ht.resource_version_id = _vid RETURNING *)
  SELECT count(*) FROM DELETED;
$$;
--}}}
