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
    WHERE resource_type = lower(_res_type)
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
    WHERE resource_type = lower(_res_type)
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
    FROM tag
    WHERE resource_type = lower(_res_type)
    AND resource_id = _id
    AND resource_version_id = _vid
    GROUP BY scheme, term, label) tgs
$$ IMMUTABLE;

-- Affix tag to resource with _id
DROP FUNCTION IF EXISTS affix_tags(_res_type varchar, _id uuid, _tags jsonb);
CREATE OR REPLACE FUNCTION
affix_tags(_res_type varchar, _id uuid, _tags jsonb)
RETURNS varchar LANGUAGE sql AS $$
  SELECT ''::varchar;
$$;

-- Affix tag to resource with _id and _vid
DROP FUNCTION IF EXISTS affix_tags(_res_type varchar, _id uuid, _vid uuid, _tags jsonb);
CREATE OR REPLACE FUNCTION
affix_tags(_res_type varchar, _id uuid, _vid uuid, _tags jsonb)
RETURNS varchar LANGUAGE sql AS $$
SELECT ''::varchar;
$$;

-- Remove all tag from current version of resource with _id
DROP FUNCTION IF EXISTS remove_tags(_res_type varchar, _id uuid);
CREATE OR REPLACE FUNCTION
remove_tags(_res_type varchar, _id uuid)
RETURNS void LANGUAGE sql AS $$
  DELETE FROM tag
    WHERE resource_type = lower(_res_type)
    AND resource_id = _id;
$$;

-- Remove all tag from resource with _id and _vid
DROP FUNCTION IF EXISTS remove_tags(_res_type varchar, _id uuid, _vid uuid);
CREATE OR REPLACE FUNCTION
remove_tags(_res_type varchar, _id uuid, _vid uuid)
RETURNS void LANGUAGE sql AS $$
  DELETE FROM history_tag
    WHERE resource_type = lower(_res_type)
    AND resource_id = _id
    AND resource_version_id = _vid;
$$;
--}}}
