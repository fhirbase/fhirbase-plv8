-- #import ./jsonbext.sql
-- #import ./gen.sql
-- #import ./coll.sql
-- #import ./util.sql
-- #import ./generate.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for ilike optimisation in search

func _sha1(x text) RETURNS text
  SELECT encode(digest(x, 'sha1'), 'hex')

func gen_version_id(_res_ jsonb) RETURNS text
  -- remove meta
  SELECT --this._sha1(jsonbext.assoc(_res_, 'meta', '[]')::text)
    gen_random_uuid()::text

func gen_logical_id(_res_ jsonb) RETURNS text
  -- remove meta
  SELECT --this._sha1(jsonbext.assoc(_res_, 'meta', '[]')::text)
    gen_random_uuid()::text

-- TODO: rename

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

--- NEW API
--- NEW API

func! read(_cfg_ jsonb, _id_ text) RETURNS jsonb
   SELECT content FROM resource WHERE logical_id = this._extract_id(_id_) limit 1

func! vread(_cfg_ jsonb, _id_ text) RETURNS jsonb
   SELECT content FROM (
     SELECT content FROM resource WHERE version_id = this._extract_vid(_id_)
     UNION
     SELECT content FROM resource_history WHERE version_id = this._extract_vid(_id_)
  ) _ LIMIT 1

proc! create(_cfg_ jsonb, _resource_ jsonb) RETURNS jsonb
  _id_ text;
  _published_ timestamptz :=  CURRENT_TIMESTAMP;
  _type_ text;
  _vid_ text;
  _meta_ jsonb;
  BEGIN
    _type_ := lower(_resource_->>'resourceType');
    _id_ := _resource_->>'id';
    _vid_ := this.gen_version_id(_resource_);

    IF _id_ is NULL THEN
      _id_ := _vid_;
      _resource_ := jsonbext.assoc(_resource_, 'id', ('"' || _id_ || '"')::jsonb);
    END IF;

    _meta_ := jsonbext.merge(
      COALESCE(_resource_->'meta','{}'::jsonb),
      json_build_object(
       'versionId', _vid_,
      'lastUpdated', _published_
      )::jsonb
    );

    _resource_ := jsonbext.assoc(_resource_, 'meta', _meta_);

    EXECUTE
      format('INSERT INTO %I (logical_id, version_id, published, updated, content) VALUES ($1, $2, $3, $4, $5)', lower(_type_))
      USING _id_, _vid_, _published_, _published_, _resource_;

    RETURN this.read(_cfg_, _id_);


-- TODO versionId as md5 or sha1
proc! update(_cfg_ jsonb, _resource_ jsonb) RETURNS jsonb
  -- Update resource, creating new version\nReturns bundle with one entry
  --TODO: detect when content not changed
  _id_ text;
  _old_vid_ text;
  _new_vid_ text;
  _vid_check_ text;
  _updated_ timestamptz;
  _resource_type_ text;
  BEGIN
    _id_ := _resource_->>'id';
    _old_vid_ := _resource_#>>'{meta,versionId}';
    _resource_type_ := _resource_->>'resourceType';

    IF _old_vid_ IS NULL OR _id_ IS NULL THEN
      RAISE EXCEPTION 'id and meta.versionId are required';
    END IF;

    SELECT version_id INTO _vid_check_ FROM resource
       WHERE logical_id = _id_ AND resource_type = _resource_type_;

    IF _vid_check_ <> _old_vid_ OR _vid_check_ IS NULL THEN
      RAISE EXCEPTION 'expected last versionId %, but got %', _vid_check_, _old_vid_;
    END IF;

    EXECUTE
      gen._tpl($SQL$
        INSERT INTO "{{tbl}}_history"
          (logical_id, version_id, published, updated, content, category)
          SELECT
          logical_id, version_id, published, updated, content, category
          FROM "{{tbl}}" WHERE version_id = $1 LIMIT 1
      $SQL$, 'tbl', lower(_resource_type_))
    USING _old_vid_;

    _updated_ := current_timestamp + interval '1 microseconds';
    _new_vid_ := this.gen_version_id(_resource_);
    _resource_ := jsonbext.assoc(_resource_, 'meta',
      jsonbext.merge(_resource_->'meta',
        json_build_object(
          'versionId', _new_vid_,
          'lastUpdated', _updated_
        )::jsonb
      )
    );

    EXECUTE
      gen._tpl($SQL$
        UPDATE "{{tbl}}" SET
        version_id = $2,
        content = $3,
        updated = $4
        WHERE version_id = $1
      $SQL$, 'tbl', lower(_resource_type_))
    USING _old_vid_, _new_vid_, _resource_, _updated_;

    RETURN this.read(_cfg_, _id_);

proc! delete(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS jsonb
  -- Update resource, creating new version\nReturns bundle with one entry
  _resource_ jsonb;
  BEGIN
    -- TODO: move old one to history, update existing
    _resource_ := this.read(_cfg_, _id_);

    IF _resource_ IS NULL THEN
      IF this.is_deleted(_cfg_, _resource_type_, _id_) THEN
        RAISE EXCEPTION 'resource with id="%s" already deleted', _id_;
      ELSE
        RAISE EXCEPTION 'resource with id="%s" does not exist', _id_;
      END IF;
    END IF;

    EXECUTE
      gen._tpl($SQL$
        INSERT INTO "{{tbl}}_history"
            (logical_id, version_id, published, updated, content)
          SELECT
             logical_id, version_id, published, updated, content
          FROM "{{tbl}}" WHERE logical_id = $1 LIMIT 1;

        DELETE FROM "{{tbl}}" WHERE logical_id = $1
      $SQL$, 'tbl', lower(_resource_type_))
    USING this._extract_id(_id_);

    RETURN _resource_;

func! is_deleted(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS boolean
  SELECT
  EXISTS (
    SELECT * FROM resource_history
     WHERE resource_type = _resource_type_
       AND logical_id = this._extract_id(_id_)
  ) AND NOT EXISTS (
    SELECT * FROM resource
     WHERE resource_type = _resource_type_
       AND logical_id = this._extract_id(_id_)
  )

func! is_latest(_cfg_ jsonb, _resource_type_ text, _id_ text, _vid_ text) RETURNS boolean
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _resource_type_
       AND r.logical_id = this._extract_id(_id_)
       AND r.version_id = this._extract_vid(_vid_)
    )

func! is_exists(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS boolean
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _resource_type_
       AND r.logical_id = this._extract_id(_id_)
    )

func _history_bundle(_cfg_ jsonb, _entries_ jsonb) RETURNS jsonb
  SELECT json_build_object(
    'type', 'history',
    'resourceType', 'Bundle',
    'entry', _entries_
  )::jsonb

func! history(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS jsonb
  WITH entry AS (
    SELECT json_build_object('resource', r.content)::jsonb as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _resource_type_
           AND logical_id = this._extract_id(_id_)
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _resource_type_
           AND logical_id = this._extract_id(_id_)
      ) r ORDER BY r.updated desc
  )
  SELECT this._history_bundle(_cfg_, json_agg(entry)::jsonb)
    FROM entry


func! history(_cfg_ jsonb, _resource_type_ text) RETURNS jsonb
  WITH entry AS (
    SELECT json_build_object('resource', r.content)::jsonb as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _resource_type_
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _resource_type_
      ) r ORDER BY r.updated desc
  )
  SELECT this._history_bundle(_cfg_, json_agg(entry)::jsonb)
    FROM entry

func! history(_cfg_ jsonb) RETURNS jsonb
  WITH entry AS (
    SELECT json_build_object('resource', r.content)::jsonb as entry
      FROM (
        SELECT * FROM resource
        UNION
        SELECT * FROM resource_history
      ) r ORDER BY r.updated desc
  )
  SELECT this._history_bundle(_cfg_, json_agg(entry)::jsonb)
    FROM entry
