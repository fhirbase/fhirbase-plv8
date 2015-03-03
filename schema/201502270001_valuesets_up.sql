update structuredefinition set installed = true
  where name in ('ValueSet', 'ConceptMap');

func assoc(_from_ jsonb, _key_ text, _value_ jsonb) RETURNS jsonb
   SELECT json_object_agg(key, value)::jsonb FROM (
     SELECT * FROM (
       SELECT x.*, 'a' as tp FROM jsonb_each(_from_) x
       UNION SELECT _key_ as key, _value_ as value, 'b' as tp
     ) _ ORDER BY tp
   ) _

func merge(_to_ jsonb, _from_ jsonb) RETURNS jsonb
   SELECT json_object_agg(key, value)::jsonb FROM (
     SELECT * FROM (
       SELECT x.*, 'a' as tp FROM jsonb_each(_to_) x
       UNION
       SELECT y.*, 'b' as tp FROM jsonb_each(_from_) y
     ) _ ORDER BY tp
   ) _

func _sha1(x text) RETURNS text
  SELECT encode(digest(x, 'sha1'), 'hex')

func gen_version_id(_res_ jsonb) RETURNS text
  -- remove meta
  SELECT this._sha1(this.assoc(_res_, 'meta', '[]')::text)

func gen_logical_id(_res_ jsonb) RETURNS text
  -- remove meta
  SELECT this._sha1(this.assoc(_res_, 'meta', '[]')::text)

proc! create(_cfg_ jsonb, _resource_ jsonb) RETURNS integer
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
      _resource_ := this.assoc(_resource_, 'id', ('"' || _id_ || '"')::jsonb);
    END IF;

    _meta_ := this.merge(
      COALESCE(_resource_->'meta','{}'::jsonb),
      json_build_object(
       'versionId', _vid_,
      'lastUpdated', _published_
      )::jsonb
    );

    _resource_ := this.assoc(_resource_, 'meta', _meta_);

    EXECUTE
      format('INSERT INTO %I (logical_id, version_id, published, updated, content) VALUES ($1, $2, $3, $4, $5)', lower(_type_))
      USING _id_, _vid_, _published_, _published_, _resource_;

    RETURN 1;

func! load_bundle(bundle jsonb) returns bigint
  SELECT
    count(this.create('{}'::jsonb,
        this.merge(
          x#>'{resource}',
          '{"text":{"status":"generated","div":"<div>too costy</div>"}}'::jsonb
        )))
    FROM jsonb_array_elements(bundle#>'{entry}') x;

\set valuesets `cat fhir/valuesets.json`
SELECT 'valuesets ' || this.load_bundle(:'valuesets');

\set valuesets `cat fhir/v2-tables.json`
SELECT 'v2-tables ' || this.load_bundle(:'valuesets');

\set valuesets `cat fhir/v3-codesystems.json`
SELECT 'v3-codesystems ' || this.load_bundle(:'valuesets');

\set valuesets `cat fhir/conceptmaps.json`
SELECT 'conceptmaps ' || this.load_bundle(:'valuesets');
