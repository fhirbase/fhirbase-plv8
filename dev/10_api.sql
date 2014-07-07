--db:fhirb
--{{{
CREATE OR REPLACE FUNCTION
_build_url(rel_path text) RETURNS text
LANGUAGE sql AS $$
  SELECT 'Base' || rel_path
$$;

CREATE OR REPLACE FUNCTION
_get_vid_from_url(_url_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT _last(regexp_split_to_array(_url_, '/'))
$$;

CREATE OR REPLACE FUNCTION
_build_link(_type_ varchar, _id_ uuid, _vid_  uuid) RETURNS jsonb
LANGUAGE sql AS $$
  SELECT json_build_object(
    'rel', 'self',
    'href', _build_url(lower(_type_) || '/' || _id_ || '/history/' || _vid_))::jsonb
$$;

--- # Instance Level Interactions
CREATE OR REPLACE
FUNCTION fhir_read(_type_ varchar, _id_ uuid) RETURNS jsonb -- bundle
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           r.logical_id AS id,
           r.category AS category,
           json_build_array(
             _build_link(r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
      FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _id_)
  SELECT
    json_build_object(
      'title', 'Concrete resource by id ' || _id_,
      'id', gen_random_uuid(),
      'resourceType', 'Bundle',
      'totalResults', 1,
      'updated', now(),
      'entry', (SELECT json_agg(e.*) FROM entry e)
    )::jsonb
$$;
COMMENT ON FUNCTION fhir_read(_type_ varchar, _id_ uuid)
IS 'Read the current state of the resource\nreturn bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_create(_type_ varchar, _resource_ jsonb, _tags_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
--- Create a new resource with a server assigned id
--- return bundle with one entry
  SELECT fhir_read(_type_, insert_resource(_resource_, _tags_))
$$;
COMMENT ON FUNCTION fhir_create(_type_ varchar, _resource_ jsonb, _tags_ jsonb)
IS 'Create a new resource with a server assigned id\nreturn bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_vread(_type_ varchar, _id_ uuid, _vid_ uuid) RETURNS jsonb
LANGUAGE sql AS $$
--- Read the state of a specific version of the resource
--- return bundle with one entry
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           r.logical_id AS id,
           r.category AS category,
           json_build_array(
             _build_link(r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = _id_
           AND version_id = _vid_
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = _id_
           AND version_id = _vid_) r)
  SELECT
    json_build_object(
      'title', 'Version of resource by id=' || _id_ || ' vid=' || _vid_,
      'id', gen_random_uuid(),
      'resourceType', 'Bundle',
      'totalResults', 1,
      'updated', now(),
      'entry', (SELECT json_agg(e.*) FROM entry e)
    )::jsonb
$$;
COMMENT ON FUNCTION fhir_vread(_type_ varchar, _id_ uuid, _vid_ uuid)
IS 'Read specific version of resource with _type_\nReturns bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_update(_type_ varchar, _id_ uuid, _vid_ uuid, _resource_ jsonb, _tags_ jsonb) returns jsonb
LANGUAGE sql AS $$
--- Update an existing resource by its id (ORDER BY create it if it is new)
--- return bundle with one entry
  SELECT update_resource(_id_, _resource_, _tags_);
  SELECT fhir_read(_type_, _id_);
$$;
COMMENT ON FUNCTION fhir_update(_type_ varchar, _id_ uuid, _vid_ uuid, _resource_ jsonb, _tags_ jsonb)
IS 'Update resource, creating new version\nReturns bundle with one entry';

CREATE OR REPLACE
FUNCTION fhir_delete(_type_ varchar, _id_ uuid) RETURNS jsonb
LANGUAGE sql AS $$
  WITH bundle AS (SELECT fhir_read(_type_, _id_) as bundle)
  SELECT bundle.bundle
  FROM bundle, delete_resource(_id_, _type_);
$$;
COMMENT ON FUNCTION fhir_delete(_type_ varchar, _id_ uuid)
IS 'DELETE resource by its id AND return deleted version\nReturn bundle with one deleted version entry' ;

CREATE OR REPLACE
FUNCTION fhir_history(_type_ varchar, _id_ uuid, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entry AS (
    SELECT r.content AS content,
           r.updated AS updated,
           r.published AS published,
           r.logical_id AS id,
           r.category AS category,
           json_build_array(
             _build_link(r.resource_type, r.logical_id, r.version_id)::json
           )::jsonb   AS link
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = _id_
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = _id_) r)
  SELECT
    json_build_object(
      'title', 'History of resource with id=' || _id_ ,
      'id', gen_random_uuid(),
      'resourceType', 'Bundle',
      'totalResults', count(e.*),
      'updated', now(),
      'entry', json_agg(e.*)
    )::jsonb
    FROM entry e
    GROUP BY e.id

$$;
COMMENT ON FUNCTION fhir_history(_type_ varchar, _id_ uuid, _params_ jsonb)
IS 'Retrieve the changes history for a particular resource with logical id (_id_)\nReturn bundle with entries representing versions';

/* FUNCTION fhir_history(_type_ varchar, _params_ jsonb) */
/* --- Retrieve the update history for a particular resource type */

/* FUNCTION fhir_history(_params_ jsonb) */
/* --- Retrieve the update history for all resources */


CREATE OR REPLACE
FUNCTION fhir_search(_type_ varchar, _params_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
-- TODO build query twice
  SELECT
    json_build_object(
      'title', 'Search results for ' || _params_::varchar,
      'resourceType', 'Bundle',
      'totalResults', (SELECT search_results_count(_type_, _params_)),
      'updated', now(),
      'id', gen_random_uuid(),
      'entry', COALESCE(json_agg(z.*), '[]'::json)
    )::jsonb as json
  FROM
    (SELECT y.content AS content,
            y.updated AS updated,
            y.published AS published,
            y.logical_id AS id,
            y.category AS category,
            json_build_array(
              _build_link(y.resource_type, y.logical_id, y.version_id)::json
            )::jsonb  AS link
       FROM search(_type_, _params_) y
    ) z
$$;
COMMENT ON FUNCTION fhir_search(_type_ varchar, _params_ jsonb)
IS 'Search in resources with _type_ by _params_\nReturns bundle with entries';

/* FUNCTION fhir_search(_params_ jsonb) */
/* --- SearchSearch across all resource types based on some filter criteria */


/* FUNCTION fhir_transaction(_bundle_ jsonb) */
/* --- Update, create ORDER BY delete a set of resources as a single transaction */


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
