--db:fhirb

--{{{
CREATE OR REPLACE FUNCTION
_build_url(_cfg jsonb, VARIADIC path text[]) RETURNS text
LANGUAGE sql AS $$
  SELECT _cfg->>'base' || '/' || (SELECT string_agg(x, '/') FROM unnest(path) x)
$$;

CREATE OR REPLACE FUNCTION
_build_link(_cfg jsonb, _type_ varchar, _id_ uuid, _vid_  uuid)
RETURNS jsonb
LANGUAGE sql AS $$
  SELECT json_build_object(
    'rel', 'self',
    'href', _build_url(_cfg, _type_, _id_::text, '_history', _vid_::text)
  )::jsonb
$$;

CREATE OR REPLACE FUNCTION
_build_id(_cfg jsonb, _type_ varchar, _id_ uuid)
RETURNS text
LANGUAGE sql AS $$
  SELECT _build_url(_cfg, _type_, _id_::text)
$$;

CREATE OR REPLACE FUNCTION
_extract_id(_id_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT _last(regexp_split_to_array((regexp_split_to_array(_id_, '/_history/')::varchar[])[1], '/'));
$$;

CREATE OR REPLACE FUNCTION
_extract_vid(_id_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT _last(regexp_split_to_array(_id_, '/_history/'));
$$;

CREATE OR REPLACE FUNCTION
_build_bundle(_title_ varchar, _total_ integer, _entry_ json) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT  json_build_object(
    'title', _title_,
    'id', gen_random_uuid(),
    'resourceType', 'Bundle',
    'totalResults', _total_,
    'updated', now(),
    'entry', _entry_
  )::jsonb

$$;

CREATE OR REPLACE
FUNCTION _build_entry(_cfg jsonb, _type text, _line "resource")
RETURNS json
LANGUAGE sql AS $$
  SELECT json_agg(x)::json FROM (
    SELECT _line.content,
           _line.updated,
           _line.published AS published,
           _build_id(_cfg, _type, _line.logical_id) AS id,
           _line.category,
           json_build_array(
             _build_link(_cfg, _type, _line.logical_id, _line.version_id)::json
           )::jsonb   AS link
  ) x
$$;


--- # Instance Level Interactions
CREATE OR REPLACE
FUNCTION fhir_read(_cfg jsonb, _type_ text, _url_ text)
RETURNS jsonb -- bundle
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, _type_, row(r.*)) as entry
      FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _extract_id(_url_)::uuid)
  SELECT _build_bundle('Concrete resource by id ' || _extract_id(_url_), 1, (SELECT entry FROM entry));
$$;
COMMENT ON FUNCTION fhir_read(jsonb, text, text)
IS 'Read the current state of the resource\nReturn bundle with only one entry for uniformity';

CREATE OR REPLACE FUNCTION
fhir_create(_cfg jsonb, _type text, _resource jsonb, _tags jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  __published timestamptz :=  CURRENT_TIMESTAMP;
  __id uuid :=gen_random_uuid();
  __vid uuid := gen_random_uuid();
BEGIN
  EXECUTE
    _tpl($SQL$
      INSERT INTO "{{tbl}}"
      (logical_id, version_id, published, updated, content, category)
      VALUES
      ($1, $2, $3, $4, $5, $6)
    $SQL$, 'tbl', lower(_type))
  USING __id, __vid, __published, __published, _resource, _tags;

  RETURN fhir_read(_cfg, _type, __id::text);
END
$$;

COMMENT ON FUNCTION fhir_create(jsonb, text, jsonb, jsonb)
IS 'Create a new resource with a server assigned id\n Return bundle with newly entry';


CREATE OR REPLACE
FUNCTION fhir_vread(_cfg jsonb, _type_ varchar, _url_ varchar) RETURNS jsonb
LANGUAGE sql AS $$
--- Read the state of a specific version of the resource
--- return bundle with one entry
  WITH entry AS (
    SELECT _build_entry(_cfg, _type_, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
           AND version_id = _extract_vid(_url_)::uuid
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
           AND version_id = _extract_vid(_url_)::uuid) r)
  SELECT _build_bundle('Version of resource by id=' || _extract_id(_url_) || ' vid=' || _extract_vid(_url_), 1, (SELECT entry FROM entry e));
$$;
COMMENT ON FUNCTION fhir_vread(_cfg jsonb, _type_ varchar, _url_ varchar)
IS 'Read specific version of resource with _type_\nReturns bundle with one entry';

--}}}

--CREATE OR REPLACE
--FUNCTION fhir_update(_cfg jsonb, _type_ varchar, _url_ varchar, _location_ varchar, _resource_ jsonb, _tags_ jsonb) returns jsonb
--LANGUAGE plpgsql AS $$
--DECLARE
--  vid uuid;
--BEGIN
----- Update an existing resource by its id (ORDER BY create it if it is new)
----- return bundle with one entry
--  vid := (
--    SELECT version_id
--    FROM resource
--    WHERE logical_id = _extract_id(_url_)::uuid);
--  IF _extract_vid(_location_)::uuid = vid THEN
--    PERFORM update_resource(_extract_id(_url_)::uuid, _resource_, _tags_);
--    RETURN fhir_read(_cfg, _type_, _url_);
--  ELSE
--    RAISE EXCEPTION E'Wrong version_id %. Current is %', _extract_vid(_location_), vid;
--  END IF;
--END
--$$;
--COMMENT ON FUNCTION fhir_update(_cfg jsonb, _type_ varchar, _url_ varchar, _location_ varchar, _resource_ jsonb, _tags_ jsonb)
--IS 'Update resource, creating new version\nReturns bundle with one entry';
--
--CREATE OR REPLACE
--FUNCTION fhir_delete(_cfg jsonb, _type_ varchar, _url_ varchar) RETURNS jsonb
--LANGUAGE sql AS $$
--  WITH bundle AS (SELECT fhir_read(_cfg, _type_, _url_) as bundle)
--  SELECT bundle.bundle
--  FROM bundle, delete_resource(_extract_id(_url_)::uuid, _type_);
--$$;
--COMMENT ON FUNCTION fhir_delete(_cfg jsonb, _type_ varchar, _url_ varchar)
--IS 'DELETE resource by its id AND return deleted version\nReturn bundle with one deleted version entry' ;
--
--CREATE OR REPLACE
--FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _url_ varchar, _params_ jsonb) RETURNS jsonb
--LANGUAGE sql AS $$
--  WITH entry AS (
--    SELECT r.content AS content,
--           r.updated AS updated,
--           r.published AS published,
--           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
--           r.category AS category,
--           json_build_array(
--             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
--           )::jsonb   AS link
--      FROM (
--        SELECT * FROM resource
--         WHERE resource_type = _type_
--           AND logical_id = _extract_id(_url_)::uuid
--        UNION
--        SELECT * FROM resource_history
--         WHERE resource_type = _type_
--           AND logical_id = _extract_id(_url_)::uuid) r)
--  SELECT _build_bundle('History of resource with id=' || _extract_id(_url_), count(e.*)::integer, COALESCE(json_agg(e.*), '[]'::json))
--  FROM entry e;
--$$;
--COMMENT ON FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _url_ varchar, _params_ jsonb)
--IS 'Retrieve the changes history for a particular resource with logical id (_id_)\nReturn bundle with entries representing versions';
--
--CREATE OR REPLACE
--FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _params_ jsonb) RETURNS jsonb
--LANGUAGE sql AS $$
--  WITH entry AS (
--    SELECT r.content AS content,
--           r.updated AS updated,
--           r.published AS published,
--           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
--           r.category AS category,
--           json_build_array(
--             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
--           )::jsonb   AS link
--      FROM (
--        SELECT * FROM resource
--         WHERE resource_type = _type_
--        UNION
--        SELECT * FROM resource_history
--         WHERE resource_type = _type_) r)
--  SELECT _build_bundle('History of resource with type=' || _type_, count(e.*)::integer, COALESCE(json_agg(e.*), '[]'::json))
--  FROM entry e;
--$$;
--COMMENT ON FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _params_ jsonb)
--IS 'Retrieve the update history for a particular resource type\nReturn bundle with entries representing versions';
--
--CREATE OR REPLACE
--FUNCTION fhir_history(_cfg jsonb, _params_ jsonb) RETURNS jsonb
--LANGUAGE sql AS $$
--  WITH entry AS (
--    SELECT r.content AS content,
--           r.updated AS updated,
--           r.published AS published,
--           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
--           r.category AS category,
--           json_build_array(
--             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
--           )::jsonb   AS link
--      FROM (
--        SELECT * FROM resource
--        UNION
--        SELECT * FROM resource_history) r)
--  SELECT _build_bundle('History of all resources', count(e.*)::integer, COALESCE(json_agg(e.*), '[]'::json))
--  FROM entry e;
--$$;
--COMMENT ON FUNCTION fhir_history(_cfg jsonb, _params_ jsonb)
--IS 'Retrieve the update history for all resources\nReturn bundle with entries representing versions';
--
--CREATE OR REPLACE
--FUNCTION fhir_is_latest_resource(_cfg jsonb, _type_ varchar, _id_ varchar, _vid_ varchar) RETURNS boolean
--LANGUAGE sql AS $$
--    SELECT EXISTS (
--      SELECT * FROM resource r
--     WHERE r.resource_type = _type_
--       AND r.logical_id = _id_::uuid
--       AND r.version_id = _vid_::uuid
--    )
--$$;
--COMMENT ON FUNCTION fhir_is_latest_resource(_cfg jsonb, _type_ varchar, _id_ varchar, _vid_ varchar)
--IS 'Check if resource is latest version';
--
--CREATE OR REPLACE
--FUNCTION fhir_is_deleted_resource(_cfg jsonb, _type_ varchar, _id_ varchar) RETURNS boolean
--LANGUAGE sql AS $$
--  SELECT
--  EXISTS (
--    SELECT * FROM resource_history
--     WHERE resource_type = _type_
--       AND logical_id = _id_::uuid
--  ) AND NOT EXISTS (
--    SELECT * FROM resource
--     WHERE resource_type = _type_
--       AND logical_id = _id_::uuid
--  )
--$$;
--COMMENT ON FUNCTION fhir_is_deleted_resource(_cfg jsonb, _type_ varchar, _id_ varchar)
--IS 'Check resource is deleted';
--}}}
