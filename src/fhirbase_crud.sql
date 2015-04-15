-- #import ./fhirbase_json.sql
-- #import ./fhirbase_gen.sql
-- #import ./fhirbase_coll.sql
-- #import ./fhirbase_util.sql
-- #import ./fhirbase_generate.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for ilike optimisation in search

func _sha1(x text) RETURNS text
  SELECT encode(digest(x, 'sha1'), 'hex')

func gen_version_id(_res_ jsonb) RETURNS text
  -- remove meta
  SELECT --this._sha1(fhirbase_json.assoc(_res_, 'meta', '[]')::text)
    gen_random_uuid()::text

func gen_logical_id(_res_ jsonb) RETURNS text
  -- remove meta
  SELECT --this._sha1(fhirbase_json.assoc(_res_, 'meta', '[]')::text)
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
  SELECT fhirbase_coll._last(regexp_split_to_array((regexp_split_to_array(_id_, '/_history/')::text[])[1], '/'));

func _extract_vid(_id_ text) RETURNS text
  -- TODO: raise if not valid url
  SELECT fhirbase_coll._last(regexp_split_to_array(_id_, '/_history/'));

func _simple_outcome(_severity_ text, _code_ text, _display_ text, _details_ text) RETURNS jsonb
   SELECT json_build_object(
     'resourceType', 'OperationOutcome',
     'issue', ARRAY[
        json_build_object(
          'severity', _severity_,
          'details', _details_,
          'code', json_build_object(
            'coding', ARRAY[
               '{"system": "http://hl7.org/fhir/issue-type","code": "invalid", "display": "Invalid Content" }'::json,
               json_build_object(
                'system', 'http://hl7.org/fhir/http-code',
                'display', _display_,
                'code', _code_
               )
            ]
          )
        )
     ])::jsonb

func! _resource_type_installed(_type_ text) RETURNS boolean
  SELECT COALESCE(
    (SELECT installed
      FROM structuredefinition
      where name = _type_
      AND installed = true LIMIT 1),
  false)

--- NEW API
--- NEW API

func! read(_cfg_ jsonb, _id_ text) RETURNS jsonb
   SELECT COALESCE(
     (SELECT content FROM resource WHERE logical_id = this._extract_id(_id_) limit 1),
     COALESCE(
       (SELECT this._simple_outcome('error', '410', 'Gone', format('Resource with id = %s was removed', _id_))
          FROM resource_history WHERE logical_id = this._extract_id(_id_) limit 1),
       this._simple_outcome('error', '404', 'Not Found', format('Resource with id = %s not found', _id_))
     )
   )

func! vread(_cfg_ jsonb, _id_ text) RETURNS jsonb
  SELECT COALESCE(
    (
     SELECT content FROM (
       SELECT content FROM resource WHERE version_id = this._extract_vid(_id_)
       UNION
       SELECT content FROM resource_history WHERE version_id = this._extract_vid(_id_)
     ) _ LIMIT 1
    ),
    this._simple_outcome('error', '404', 'Not Found', format('Resource with versionId = %s not found', _id_))
  )


proc! create(_cfg_ jsonb, _resource_ jsonb) RETURNS jsonb
  _id_ text;
  _published_ timestamptz :=  CURRENT_TIMESTAMP;
  _flag_ boolean;
  _type_ text;
  _vid_ text;
  _meta_ jsonb;
  BEGIN
    _type_ := lower(_resource_->>'resourceType');
    _id_ := _resource_->>'id';
    _vid_ := this.gen_version_id(_resource_);

    IF  NOT this._resource_type_installed(_resource_->>'resourceType') THEN
      RETURN this._simple_outcome('error',
        '404', 'Not Found',
        'resource type ' || (_resource_->>'resourceType')  || ' not supported, or not a FHIR end point'
      );
    END IF;

    IF _id_ IS NOT NULL THEN
      RETURN this._simple_outcome('error',
        '400', 'Bad Request',
        'The request body SHALL be a FHIR Resource without an id element.  If the client wishes to have control over the id of a newly submitted resource, it should use the update interaction instead.  See: http://hl7-fhir.github.io/http.html#2.1.0.13'
      );
    END IF;

    _id_ := _vid_;
    _resource_ := fhirbase_json.assoc(_resource_, 'id', ('"' || _id_ || '"')::jsonb);

    _meta_ := fhirbase_json.merge(
      COALESCE(_resource_->'meta','{}'::jsonb),
      json_build_object(
       'versionId', _vid_,
      'lastUpdated', _published_
      )::jsonb
    );

    _resource_ := fhirbase_json.assoc(_resource_, 'meta', _meta_);

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
  _updated_ timestamptz :=  CURRENT_TIMESTAMP;
  _resource_type_ text;
  BEGIN
    _id_ := _resource_->>'id';
    _old_vid_ := _resource_#>>'{meta,versionId}';
    _new_vid_ := this.gen_version_id(_resource_);
    _resource_type_ := _resource_->>'resourceType';

    IF  NOT this._resource_type_installed(_resource_->>'resourceType') THEN
      RETURN this._simple_outcome('error',
        '404', 'Not Found',
        'resource type ' || (_resource_->>'resourceType')  || ' not supported, or not a FHIR end point'
      );
    END IF;

    IF _id_ IS NULL THEN
      RETURN this._simple_outcome('error',
        '422', 'Unprocessable Entity',
        'The request body SHALL be a Resource with an id element'
      );
    END IF;

    SELECT version_id INTO _vid_check_ FROM resource
    WHERE logical_id = _id_ AND resource_type = _resource_type_;

    IF coalesce(_vid_check_, '') <> coalesce(_old_vid_, '') THEN
      RETURN this._simple_outcome('error',
        '422', 'Unprocessable Entity',
        format('If you pass meta.versionId we go against FHIR spec and check for version conflicts. Expected last versionId %s, but got %s', _vid_check_, _old_vid_)
      );
    END IF;

    IF _old_vid_ IS NOT NULL THEN
      EXECUTE
      fhirbase_gen._tpl($SQL$
        INSERT INTO "{{tbl}}_history"
          (logical_id, version_id, published, updated, content, category)
          SELECT
          logical_id, version_id, published, updated, content, category
          FROM "{{tbl}}" WHERE version_id = $1 LIMIT 1
        $SQL$, 'tbl', lower(_resource_type_))
      USING _old_vid_;
    END IF;

    _resource_ := fhirbase_json.assoc(_resource_, 'meta',
      fhirbase_json.merge(_resource_->'meta',
        json_build_object(
          'versionId', _new_vid_,
          'lastUpdated', _updated_
        )::jsonb
      )
    );

    IF _old_vid_ IS NULL THEN
      EXECUTE
        format('INSERT INTO %I (logical_id, version_id, published, updated, content) VALUES ($1, $2, $3, $4, $5)', lower(_resource_type_))
      USING _id_, _new_vid_, _updated_, _updated_, _resource_;
    ELSE
      EXECUTE
      fhirbase_gen._tpl($SQL$
        UPDATE "{{tbl}}" SET
        version_id = $2,
        content = $3,
        updated = $4
        WHERE version_id = $1
      $SQL$, 'tbl', lower(_resource_type_))
      USING _old_vid_, _new_vid_, _resource_, _updated_;
    END IF;

    RETURN this.read(_cfg_, _id_);

proc! delete(_cfg_ jsonb, _resource_type_ text, _id_ text) RETURNS jsonb
  -- Update resource, creating new version\nReturns bundle with one entry
  _resource_ jsonb;
  BEGIN
    -- TODO: move old one to history, update existing
    _resource_ := this.read(_cfg_, _id_);

    IF _resource_->>'resourceType' = 'OperationOutcome' THEN
      RETURN _resource_;
    END IF;

    EXECUTE
      fhirbase_gen._tpl($SQL$
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
