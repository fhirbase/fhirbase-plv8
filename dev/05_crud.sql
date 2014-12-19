--db:fhirb

--{{{
CREATE OR REPLACE FUNCTION
_build_url(_cfg jsonb, VARIADIC path text[]) RETURNS text
LANGUAGE sql AS $$
  SELECT _cfg->>'base' || '/' || (SELECT string_agg(x, '/') FROM unnest(path) x)
$$;

CREATE OR REPLACE FUNCTION
_build_link(_cfg jsonb, _type_ text, _id_ uuid, _vid_  uuid)
RETURNS jsonb
LANGUAGE sql AS $$
  SELECT json_build_object(
    'rel', 'self',
    'href', _build_url(_cfg, _type_, _id_::text, '_history', _vid_::text)
  )::jsonb
$$;

CREATE OR REPLACE FUNCTION
_build_id(_cfg jsonb, _type_ text, _id_ uuid)
RETURNS text
LANGUAGE sql AS $$
  SELECT _build_url(_cfg, _type_, _id_::text)
$$;

CREATE OR REPLACE FUNCTION
_extract_id(_id_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT _last(regexp_split_to_array((regexp_split_to_array(_id_, '/_history/')::text[])[1], '/'));
$$;

CREATE OR REPLACE FUNCTION
_extract_vid(_id_ text) RETURNS text
LANGUAGE sql AS $$
  -- TODO: raise if not valid url
  SELECT _last(regexp_split_to_array(_id_, '/_history/'));
$$;

CREATE OR REPLACE FUNCTION
_build_bundle(_title_ text, _total_ integer, _entry_ json) RETURNS jsonb
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
FUNCTION _build_entry(_cfg jsonb, _line "resource")
RETURNS json
LANGUAGE sql AS $$
  SELECT row_to_json(x.*) FROM (
    SELECT _line.content,
           _line.updated,
           _line.published AS published,
           _build_id(_cfg, _line.resource_type, _line.logical_id) AS id,
           _line.category,
           json_build_array(
             _build_link(_cfg, _line.resource_type, _line.logical_id, _line.version_id)::json
           )::jsonb   AS link
  ) x
$$;


--- # Instance Level Interactions
CREATE OR REPLACE
FUNCTION fhir_read(_cfg jsonb, _type_ text, _url_ text)
RETURNS jsonb -- bundle
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _extract_id(_url_)::uuid)
  SELECT _build_bundle('Concrete resource by id ' || _extract_id(_url_), 1, (SELECT json_agg(entry) FROM entry));
$$;

CREATE OR REPLACE FUNCTION
fhir_create(_cfg jsonb, _type text, _id uuid, _resource jsonb, _tags jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  __published timestamptz :=  CURRENT_TIMESTAMP;
  __vid uuid := gen_random_uuid();
BEGIN
  EXECUTE
    _tpl($SQL$
      INSERT INTO "{{tbl}}"
      (logical_id, version_id, published, updated, content, category)
      VALUES
      ($1, $2, $3, $4, $5, $6)
    $SQL$, 'tbl', lower(_type))
  USING _id, __vid, __published, __published, _resource, _tags;

  RETURN fhir_read(_cfg, _type, _id::text);
END
$$;

CREATE OR REPLACE FUNCTION
fhir_create(_cfg jsonb, _type text, _resource jsonb, _tags jsonb)
RETURNS jsonb LANGUAGE sql AS $$
  SELECT fhir_create(_cfg, _type, gen_random_uuid(), _resource, _tags);
$$;

CREATE OR REPLACE FUNCTION
fhir_create(_cfg jsonb, _type text, _resource jsonb)
RETURNS jsonb LANGUAGE sql AS $$
  SELECT fhir_create(_cfg, _type, gen_random_uuid(), _resource, '[]'::jsonb);
$$;

CREATE OR REPLACE FUNCTION
fhir_create(_cfg jsonb, _resource jsonb)
RETURNS jsonb LANGUAGE sql AS $$
  SELECT fhir_create(_cfg, (_resource->>'resourceType'), gen_random_uuid(), _resource, '[]'::jsonb);
$$;

CREATE OR REPLACE
FUNCTION fhir_vread(_cfg jsonb, _type_ text, _url_ text) RETURNS jsonb
LANGUAGE sql AS $$
--- Read the state of a specific version of the resource
--- return bundle with one entry
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
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
  SELECT _build_bundle('Version of resource by id=' || _extract_id(_url_) || ' vid=' || _extract_vid(_url_),
    1,
    (SELECT json_agg(entry) FROM entry e));
$$;
COMMENT ON FUNCTION fhir_vread(_cfg jsonb, _type_ text, _url_ text)
IS 'Read specific version of resource with _type_\nReturns bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_update(_cfg jsonb, _type text, _url_ text, _location_ text, _resource_ jsonb, _tags_ jsonb)
RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  __vid uuid;
BEGIN
  __vid := (SELECT version_id FROM resource WHERE logical_id = _extract_id(_url_)::uuid);

  IF _extract_vid(_location_)::uuid <> __vid THEN
    RAISE EXCEPTION E'Wrong version_id %. Current is %',
    _extract_vid(_location_), __vid;
    RETURN NULL;
  END IF;

  EXECUTE
    _tpl($SQL$
      INSERT INTO "{{tbl}}_history"
      (logical_id, version_id, published, updated, content, category)
      SELECT
      logical_id, version_id, published, current_timestamp, content, category
      FROM "{{tbl}}" WHERE version_id = $1 LIMIT 1
    $SQL$, 'tbl', lower(_type))
  USING __vid;

  EXECUTE
    _tpl($SQL$
      UPDATE "{{tbl}}" SET
      version_id = gen_random_uuid(),
      content = $2,
      category = _merge_tags(category, $3),
      updated = current_timestamp
      WHERE version_id = $1
    $SQL$, 'tbl', lower(_type))
  USING __vid, _resource_, _tags_;

  RETURN fhir_read(_cfg, _type , _extract_id(_url_));
END
$$;
COMMENT ON FUNCTION fhir_update(_cfg jsonb, _type text, _url_ text, _location_ text, _resource_ jsonb, _tags_ jsonb)
IS 'Update resource, creating new version\nReturns bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_delete(_cfg jsonb, _type text, _url text)
RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  __bundle jsonb;
BEGIN
  __bundle := fhir_read(_cfg, _type, _url);

  EXECUTE
    _tpl($SQL$
      INSERT INTO "{{tbl}}_history"
      (logical_id, version_id, published, updated, content, category)
      SELECT
      logical_id, version_id, published, current_timestamp, content, category
      FROM "{{tbl}}" WHERE logical_id = $1 LIMIT 1;

      DELETE FROM "{{tbl}}" WHERE logical_id = $1;
    $SQL$, 'tbl', lower(_type))
  USING _extract_id(_url)::uuid;

  RETURN __bundle;
END
$$;

CREATE OR REPLACE
FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _url_ varchar, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
      ) r
  )
  SELECT _build_bundle(
    'History of resource by id=' || _extract_id(_url_),
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );
$$;


CREATE OR REPLACE
FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
      ) r
  )
  SELECT _build_bundle(
    'History of resource by type =' || _type_,
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );
$$;

CREATE OR REPLACE
FUNCTION fhir_history(_cfg jsonb, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
        UNION
        SELECT * FROM resource_history
      ) r
  )
  SELECT _build_bundle(
    'History of all resources',
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );
$$;


CREATE OR REPLACE
FUNCTION fhir_is_latest_resource(_cfg jsonb, _type_ text, _id_ text, _vid_ text) RETURNS boolean
LANGUAGE sql AS $$
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _id_::uuid
       AND r.version_id = _vid_::uuid
    )
$$;

CREATE OR REPLACE
FUNCTION fhir_is_resource_exists(_cfg jsonb, _type_ text, _id_ text)
RETURNS boolean
LANGUAGE sql AS $$
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _id_::uuid
    )
$$;

CREATE OR REPLACE
FUNCTION fhir_is_deleted_resource(_cfg jsonb, _type_ text, _id_ text) RETURNS boolean
LANGUAGE sql AS $$
  SELECT
  EXISTS (
    SELECT * FROM resource_history
     WHERE resource_type = _type_
       AND logical_id = _id_::uuid
  ) AND NOT EXISTS (
    SELECT * FROM resource
     WHERE resource_type = _type_
       AND logical_id = _id_::uuid
  )
$$;
--}}}
