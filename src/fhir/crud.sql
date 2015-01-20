-- #import ../gen.sql
-- #import ../coll.sql
-- #import ../util.sql
-- #import ./generate.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for ilike optimisation in search

func _build_url(_cfg_ jsonb, VARIADIC path text[]) RETURNS text
  SELECT _cfg_->>'base' || '/' || (SELECT string_agg(x, '/') FROM unnest(path) x)

func _build_link(_cfg_ jsonb, _type_ text, _id_ text, _vid_  text) RETURNS jsonb
  SELECT json_build_object(
    'rel', 'self',
    'href', this._build_url(_cfg_, _type_, _id_::text, '_history', _vid_::text)
  )::jsonb

func _build_id(_cfg_ jsonb, _type_ text, _id_ text) RETURNS text
  SELECT this._build_url(_cfg_, _type_, _id_::text)

func _extract_id(_id_ text) RETURNS text
  SELECT coll._last(regexp_split_to_array((regexp_split_to_array(_id_, '/_history/')::text[])[1], '/'));

func _extract_vid(_id_ text) RETURNS text
  -- TODO: raise if not valid url
  SELECT coll._last(regexp_split_to_array(_id_, '/_history/'));

func _build_bundle(_title_ text, _total_ integer, _entry_ json) RETURNS jsonb
  SELECT  json_build_object(
    'title', _title_,
    'id', gen_random_uuid()::text,
    'resourceType', 'Bundle',
    'totalResults', _total_,
    'updated', now(),
    'entry', _entry_
  )::jsonb

func _build_entry(_cfg_ jsonb, _line "resource") RETURNS json
  SELECT row_to_json(x.*) FROM (
    SELECT _line.content,
           _line.updated,
           _line.published AS published,
           this._build_id(_cfg_, _line.resource_type, _line.logical_id) AS id,
           _line.category,
           json_build_array(
             this._build_link(_cfg_, _line.resource_type, _line.logical_id, _line.version_id)::json
           )::jsonb   AS link
  ) x


--- # Instance Level Interactions
func fhir_read(_cfg_ jsonb, _type_ text, _url_ text) RETURNS jsonb
  -- bundle
  WITH entry AS (
    SELECT this._build_entry(_cfg_, row(r.*)) as entry
      FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = this._extract_id(_url_))
  SELECT this._build_bundle('Concrete resource by id ' || this._extract_id(_url_), 1, (SELECT json_agg(entry) FROM entry));

/* TODO: guard from _cfg_ null */
proc! fhir_create(_cfg_ jsonb, _type text, _id text, _resource jsonb, _tags jsonb) RETURNS jsonb
  __published timestamptz :=  CURRENT_TIMESTAMP;
  __vid text := gen_random_uuid()::text;
  BEGIN
    EXECUTE
      gen._tpl($SQL$
        INSERT INTO "{{tbl}}"
        (logical_id, version_id, published, updated, content, category)
        VALUES
        ($1, $2, $3, $4, $5, $6)
      $SQL$, 'tbl', lower(_type))
    USING _id, __vid, __published, __published, _resource, _tags;

    RETURN this.fhir_read(_cfg_, _type, _id::text);

func fhir_create(_cfg_ jsonb, _type text, _resource jsonb, _tags jsonb) RETURNS jsonb
  SELECT this.fhir_create(_cfg_, _type, gen_random_uuid()::text, _resource, _tags)

func fhir_create(_cfg_ jsonb, _type text, _resource jsonb) RETURNS jsonb
  SELECT this.fhir_create(_cfg_, _type, gen_random_uuid()::text, _resource, '[]'::jsonb)

func fhir_create(_cfg_ jsonb, _resource jsonb) RETURNS jsonb
  SELECT this.fhir_create(_cfg_, (_resource->>'resourceType'), gen_random_uuid()::text, _resource, '[]'::jsonb)

func fhir_vread(_cfg_ jsonb, _type_ text, _url_ text) RETURNS jsonb
  --- Read the state of a specific version of the resource
  --- return bundle with one entry
  --- 'Read specific version of resource with _type_\nReturns bundle with one entry';
  WITH entry AS (
    SELECT this._build_entry(_cfg_, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = this._extract_id(_url_)
           AND version_id = this._extract_vid(_url_)
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = this._extract_id(_url_)
           AND version_id = this._extract_vid(_url_)) r)
  SELECT this._build_bundle('Version of resource by id=' || this._extract_id(_url_) || ' vid=' || this._extract_vid(_url_),
    1,
    (SELECT json_agg(entry) FROM entry e));

proc! fhir_update(_cfg_ jsonb, _type text, _url_ text, _location_ text, _resource_ jsonb, _tags_ jsonb) RETURNS jsonb
  -- Update resource, creating new version\nReturns bundle with one entry
  __vid text;
  BEGIN
    __vid := (SELECT version_id FROM resource WHERE logical_id = this._extract_id(_url_));

    IF this._extract_vid(_location_) <> __vid THEN
      RAISE EXCEPTION E'Wrong version_id %. Current is %',
      this._extract_vid(_location_), __vid;
      RETURN NULL;
    END IF;

    EXECUTE
      gen._tpl($SQL$
        INSERT INTO "{{tbl}}_history"
        (logical_id, version_id, published, updated, content, category)
        SELECT
        logical_id, version_id, published, current_timestamp, content, category
        FROM "{{tbl}}" WHERE version_id = $1 LIMIT 1
      $SQL$, 'tbl', lower(_type))
    USING __vid;

    EXECUTE
      gen._tpl($SQL$
        UPDATE "{{tbl}}" SET
        version_id = gen_random_uuid()::text,
        content = $2,
        category = util._merge_tags(category, $3),
        updated = current_timestamp
        WHERE version_id = $1
      $SQL$, 'tbl', lower(_type))
    USING __vid, _resource_, _tags_;

    RETURN this.fhir_read(_cfg_, _type , this._extract_id(_url_));

proc! fhir_delete(_cfg_ jsonb, _type text, _url text) RETURNS jsonb
  __bundle jsonb;
  BEGIN
    __bundle := this.fhir_read(_cfg_, _type, _url);

    EXECUTE
      gen._tpl($SQL$
        INSERT INTO "{{tbl}}_history"
        (logical_id, version_id, published, updated, content, category)
        SELECT
        logical_id, version_id, published, current_timestamp, content, category
        FROM "{{tbl}}" WHERE logical_id = $1 LIMIT 1;

        DELETE FROM "{{tbl}}" WHERE logical_id = $1;
      $SQL$, 'tbl', lower(_type))
    USING this._extract_id(_url);

    RETURN __bundle;

func! fhir_history(_cfg_ jsonb, _type_ text, _url_ text, _params_ jsonb) RETURNS jsonb
  WITH entry AS (
    SELECT this._build_entry(_cfg_, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = this._extract_id(_url_)
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = this._extract_id(_url_)
      ) r
  )
  SELECT this._build_bundle(
    'History of resource by id=' || this._extract_id(_url_),
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );


func! fhir_history(_cfg_ jsonb, _type_ text, _params_ jsonb) RETURNS jsonb
  WITH entry AS (
    SELECT this._build_entry(_cfg_, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
      ) r
  )
  SELECT this._build_bundle(
    'History of resource by type =' || _type_,
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );

func! fhir_history(_cfg_ jsonb, _params_ jsonb) RETURNS jsonb
  WITH entry AS (
    SELECT this._build_entry(_cfg_, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
        UNION
        SELECT * FROM resource_history
      ) r
  )
  SELECT this._build_bundle(
    'History of all resources',
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );


func! fhir_is_latest_resource(_cfg_ jsonb, _type_ text, _id_ text, _vid_ text) RETURNS boolean
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = this._extract_id(_id_)
       AND r.version_id = this._extract_vid(_vid_)
    )

func! fhir_is_resource_exists(_cfg_ jsonb, _type_ text, _id_ text) RETURNS boolean
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = this._extract_id(_id_)
    )

func! fhir_is_deleted_resource(_cfg_ jsonb, _type_ text, _id_ text) RETURNS boolean
  SELECT
  EXISTS (
    SELECT * FROM resource_history
     WHERE resource_type = _type_
       AND logical_id = this._extract_id(_id_)
  ) AND NOT EXISTS (
    SELECT * FROM resource
     WHERE resource_type = _type_
       AND logical_id = this._extract_id(_id_)
  )
