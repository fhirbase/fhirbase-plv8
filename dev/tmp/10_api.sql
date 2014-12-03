--db:fhirb
--{{{
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
  )::jsonb;
$$;

CREATE OR REPLACE FUNCTION
_build_url(_cfg jsonb, rel_path text) RETURNS text
LANGUAGE sql AS $$
  SELECT _cfg->>'base' || '/' || rel_path
$$;

CREATE OR REPLACE FUNCTION
_get_vid_from_url(_url_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT _last(regexp_split_to_array(_url_, '/'))
$$;

CREATE OR REPLACE FUNCTION
_build_link(_cfg jsonb, _type_ varchar, _id_ uuid, _vid_  uuid) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT json_build_object(
    'rel', 'self',
    'href', _build_url(_cfg, _type_ || '/' || _id_ || '/_history/' || _vid_))::jsonb
$$;

CREATE OR REPLACE FUNCTION
_build_id(_cfg jsonb, _type_ varchar, _id_ uuid) RETURNS varchar
LANGUAGE sql AS $$
  SELECT _build_url(_cfg, _type_ || '/' || _id_)
$$;

CREATE OR REPLACE FUNCTION
_extract_id(_id_ varchar) RETURNS varchar
LANGUAGE sql AS $$
  SELECT _last(regexp_split_to_array((regexp_split_to_array(_id_, '/_history/')::varchar[])[1], '/'));
$$;

CREATE OR REPLACE FUNCTION
_extract_vid(_id_ varchar) RETURNS varchar
LANGUAGE sql AS $$
  SELECT _last(regexp_split_to_array(_id_, '/_history/'));
$$;

DROP FUNCTION IF EXISTS _replace_references(_resource_ text, _references_ json[]);

CREATE OR REPLACE FUNCTION
_replace_references(_resource_ text, _references_ json[]) RETURNS text
LANGUAGE sql AS $$
  SELECT
    CASE
    WHEN array_length(_references_, 1) > 0 THEN
     _replace_references(
       replace(_resource_, _references_[1]->>'alternative', _references_[1]->>'id'),
       _rest(_references_))
    ELSE _resource_
    END;
$$;

--- # Instance Level Interactions
CREATE OR REPLACE
FUNCTION fhir_read(_cfg jsonb, _type_ varchar, _url_ varchar) RETURNS jsonb -- bundle
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
           r.category AS category,
           json_build_array(
             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
      FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _extract_id(_url_)::uuid)
  SELECT _build_bundle('Concrete resource by id ' || _extract_id(_url_), 1, (SELECT json_agg(e.*) FROM entry e));
$$;
COMMENT ON FUNCTION fhir_read(_cfg jsonb, _type_ varchar, _id_ varchar)
IS 'Read the current state of the resource\nReturn bundle with only one entry for uniformity';

CREATE OR REPLACE
FUNCTION fhir_create(_cfg jsonb, _type_ varchar, _resource_ jsonb, _tags_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
--- Create a new resource with a server assigned id
--- return bundle with one entry
  SELECT fhir_read(_cfg, _type_, _build_id(_cfg, _type_, insert_resource(_resource_, _tags_)))
$$;
COMMENT ON FUNCTION fhir_create(_cfg jsonb, _type_ varchar, _resource_ jsonb, _tags_ jsonb)
IS 'Create a new resource with a server assigned id\n Return bundle with newly entry';

CREATE OR REPLACE
FUNCTION fhir_vread(_cfg jsonb, _type_ varchar, _url_ varchar) RETURNS jsonb
LANGUAGE sql AS $$
--- Read the state of a specific version of the resource
--- return bundle with one entry
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
           r.category AS category,
           json_build_array(
             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
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
  SELECT _build_bundle('Version of resource by id=' || _extract_id(_url_) || ' vid=' || _extract_vid(_url_), 1, (SELECT json_agg(e.*) FROM entry e));
$$;
COMMENT ON FUNCTION fhir_vread(_cfg jsonb, _type_ varchar, _url_ varchar)
IS 'Read specific version of resource with _type_\nReturns bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_update(_cfg jsonb, _type_ varchar, _url_ varchar, _location_ varchar, _resource_ jsonb, _tags_ jsonb) returns jsonb
LANGUAGE plpgsql AS $$
DECLARE
  vid uuid;
BEGIN
--- Update an existing resource by its id (ORDER BY create it if it is new)
--- return bundle with one entry
  vid := (
    SELECT version_id
    FROM resource
    WHERE logical_id = _extract_id(_url_)::uuid);
  IF _extract_vid(_location_)::uuid = vid THEN
    PERFORM update_resource(_extract_id(_url_)::uuid, _resource_, _tags_);
    RETURN fhir_read(_cfg, _type_, _url_);
  ELSE
    RAISE EXCEPTION E'Wrong version_id %. Current is %', _extract_vid(_location_), vid;
  END IF;
END
$$;
COMMENT ON FUNCTION fhir_update(_cfg jsonb, _type_ varchar, _url_ varchar, _location_ varchar, _resource_ jsonb, _tags_ jsonb)
IS 'Update resource, creating new version\nReturns bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_delete(_cfg jsonb, _type_ varchar, _url_ varchar) RETURNS jsonb
LANGUAGE sql AS $$
  WITH bundle AS (SELECT fhir_read(_cfg, _type_, _url_) as bundle)
  SELECT bundle.bundle
  FROM bundle, delete_resource(_extract_id(_url_)::uuid, _type_);
$$;
COMMENT ON FUNCTION fhir_delete(_cfg jsonb, _type_ varchar, _url_ varchar)
IS 'DELETE resource by its id AND return deleted version\nReturn bundle with one deleted version entry' ;

CREATE OR REPLACE
FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _url_ varchar, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
           r.category AS category,
           json_build_array(
             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid) r)
  SELECT _build_bundle('History of resource with id=' || _extract_id(_url_), count(e.*)::integer, COALESCE(json_agg(e.*), '[]'::json))
  FROM entry e;
$$;
COMMENT ON FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _url_ varchar, _params_ jsonb)
IS 'Retrieve the changes history for a particular resource with logical id (_id_)\nReturn bundle with entries representing versions';

CREATE OR REPLACE
FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
           r.category AS category,
           json_build_array(
             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_) r)
  SELECT _build_bundle('History of resource with type=' || _type_, count(e.*)::integer, COALESCE(json_agg(e.*), '[]'::json))
  FROM entry e;
$$;
COMMENT ON FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _params_ jsonb)
IS 'Retrieve the update history for a particular resource type\nReturn bundle with entries representing versions';

CREATE OR REPLACE
FUNCTION fhir_history(_cfg jsonb, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           _build_id(_cfg, r.resource_type, r.logical_id) AS id,
           r.category AS category,
           json_build_array(
             _build_link(_cfg, r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
      FROM (
        SELECT * FROM resource
        UNION
        SELECT * FROM resource_history) r)
  SELECT _build_bundle('History of all resources', count(e.*)::integer, COALESCE(json_agg(e.*), '[]'::json))
  FROM entry e;
$$;
COMMENT ON FUNCTION fhir_history(_cfg jsonb, _params_ jsonb)
IS 'Retrieve the update history for all resources\nReturn bundle with entries representing versions';

CREATE OR REPLACE
FUNCTION fhir_search(_cfg jsonb, _type_ varchar, _params_ text) RETURNS jsonb
LANGUAGE sql AS $$
-- TODO build query twice
  SELECT _build_bundle('Search results for ' || _params_::varchar, (SELECT search_results_count(_type_, _params_))::integer, COALESCE(json_agg(z.*), '[]'::json)) as json
  FROM
    (SELECT y.content AS content,
            y.updated AS updated,
            y.published AS published,
            _build_id(_cfg, y.resource_type, y.logical_id) AS id,
            y.category AS category,
            json_build_array(
              _build_link(_cfg, y.resource_type, y.logical_id, y.version_id)::json
            )::jsonb AS link
       FROM search(_type_, _params_) y
    ) z
$$;
COMMENT ON FUNCTION fhir_search(_cfg jsonb, _type_ varchar, _params_ text)
IS 'Search in resources with _type_ by _params_\nReturns bundle with entries';

/* FUNCTION fhir_search(_params_ jsonb) */
/* --- SearchSearch across all resource types based on some filter criteria */

CREATE OR REPLACE
FUNCTION fhir_transaction(_cfg jsonb, _bundle_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entries AS (
    SELECT jsonb_array_elements(_bundle_->'entry') AS entry
  ), items AS (
    SELECT
      e.entry->>'id' AS id,
      e.entry#>>'{link,0,href}' AS vid,
      e.entry#>>'{content,resourceType}' AS resource_type,
      e.entry->'content' AS content,
      e.entry->'category' as category,
      e.entry->>'deleted' AS deleted
    FROM entries e
  ), create_resources AS (
    SELECT i.*
    FROM items i
    LEFT JOIN resource r on r.logical_id::text = _extract_id(i.id)
    WHERE i.deleted is null and r.logical_id is null
  ), created_resources AS (
    SELECT
      r.id as alternative,
      fhir_create(_cfg, r.resource_type, r.content::jsonb, r.category::jsonb)#>'{entry,0}' as entry
    FROM create_resources r
  ), reference AS (
    SELECT array(
      SELECT json_build_object('alternative', r.alternative, 'id', r.entry->>'id')
      FROM created_resources r) as refs
  ), update_resources AS (
    SELECT i.*
    FROM items i
    LEFT JOIN resource r on r.logical_id::text = _extract_id(i.id)
    WHERE i.deleted is null and r.logical_id is not null
  ), updated_resources AS (
    SELECT
      r.id as alternative,
      fhir_update(_cfg, r.resource_type, cr.entry->>'id',
        cr.entry#>>'{link,0,href}',
        _replace_references(r.content::text, rf.refs)::jsonb, '[]'::jsonb)#>'{entry,0}' as entry
    FROM create_resources r
    JOIN created_resources cr on cr.alternative = r.id
    JOIN reference rf on 1=1
    UNION ALL
    SELECT
      r.id as alternative,
      fhir_update(_cfg, r.resource_type, r.id, r.vid, _replace_references(r.content::text, rf.refs)::jsonb, r.category::jsonb)#>'{entry,0}' as entry
    FROM update_resources r, reference rf
  ), delete_resources AS (
    SELECT i.*
    FROM items i
    WHERE i.deleted is not null
  ), deleted_resources AS (
    SELECT d.alternative, d.entry
    FROM (
      SELECT
        r.id as alternative,
        ('{"id": "' || r.id || '"}')::jsonb as entry,
        fhir_delete(_cfg, rs.resource_type, r.id) as deleted
      FROM delete_resources r
      JOIN resource rs on rs.logical_id::text = _extract_id(r.id)
    ) d
  ), created AS (
    SELECT
      r.entry->'content' as content,
      r.entry->'updated' as updated,
      r.entry->'published' as published,
      r.entry->'id' as id,
      r.entry->'category' as category,
      r.entry->'link' as link,
      r.alternative as alternative
    FROM (
      SELECT *
      FROM updated_resources
      UNION ALL
      SELECT *
      FROM deleted_resources
    ) r
  )
  SELECT _build_bundle('Transaction results', count(r.*)::integer, COALESCE(json_agg(r.*), '[]'::json)) as json
  FROM created r;
$$;
COMMENT ON FUNCTION fhir_transaction(_cfg jsonb, _bundle_ jsonb)
IS 'Update, create or delete a set of resources as a single transaction\nReturns bundle with entries';

CREATE OR REPLACE
FUNCTION fhir_is_resource_exists(_cfg jsonb, _type_ varchar, _id_ varchar) RETURNS boolean
LANGUAGE sql AS $$
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _id_::uuid
    )
$$;
COMMENT ON FUNCTION fhir_is_resource_exists(_cfg jsonb, _type_ varchar, _id_ varchar)
IS 'Check if resource exists';

CREATE OR REPLACE
FUNCTION fhir_is_latest_resource(_cfg jsonb, _type_ varchar, _id_ varchar, _vid_ varchar) RETURNS boolean
LANGUAGE sql AS $$
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _id_::uuid
       AND r.version_id = _vid_::uuid
    )
$$;
COMMENT ON FUNCTION fhir_is_latest_resource(_cfg jsonb, _type_ varchar, _id_ varchar, _vid_ varchar)
IS 'Check if resource is latest version';

CREATE OR REPLACE
FUNCTION fhir_is_deleted_resource(_cfg jsonb, _type_ varchar, _id_ varchar) RETURNS boolean
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
COMMENT ON FUNCTION fhir_is_deleted_resource(_cfg jsonb, _type_ varchar, _id_ varchar)
IS 'Check resource is deleted';


/* FUNCTION fhir_conformance() */
/* --- Get a conformance statement for the system */
/* --- return conformance resource */

/* FUNCTION fhir_validate(_type_ varchar, _resource_ jsonb) */
/* --- Check that the content would be acceptable as an update */

/* FUNCTION fhir_mailbox(_bundle_) */

/* FUNCTION fhir_document() */

-- TAGS operations
-- see in tags.sql
--}}}
