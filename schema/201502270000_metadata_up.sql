func merge(_to_ jsonb, _from_ jsonb) RETURNS jsonb
   SELECT json_object_agg(key, value)::jsonb FROM (
     SELECT * FROM (
       SELECT x.*, 'a' as tp FROM jsonb_each(_to_) x
       UNION
       SELECT y.*, 'b' as tp FROM jsonb_each(_from_) y
     ) _ ORDER BY tp
   ) _

func _butlast(_ar_ anyarray) RETURNS anyarray
  --- cut last element of array
  SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1]

func _last(_ar_ anyarray) RETURNS anyelement
  --- return last element of collection
  SELECT _ar_[array_length(_ar_,1)];

func structuredefinition_to_resource_type(_ref_ text) RETURNS text
  select replace(_ref_, 'http://hl7.org/fhir/StructureDefinition/', '')

func! load_elements(_prof_ jsonb) returns text
 with inserted as (
    INSERT INTO structuredefinition_elements
    (structuredefinition_id, path, min, max, type, formal, comments, isSummary, ref_type)
    select
      _prof_->>'id',
      regexp_split_to_array(x->>'path', '\.'),
      x->>'min',
      x->>'max',
      (
        SELECT array_agg(y->>'code')
        FROM jsonb_array_elements(x->'type') y
        WHERE y->>'code' <> 'Reference'
      ),
      x->>'formal',
      x->>'comments',
      x->>'isSummary' = 'true',
      (
        SELECT array_agg(this.structuredefinition_to_resource_type(y->>'structuredefinition'))
         FROM jsonb_array_elements(x->'type') y
         WHERE y->>'code' = 'Reference'
      )
      from jsonb_array_elements(_prof_#>'{snapshot, element}') x
      WHERE x->>'path' <> 'value' AND jsonb_typeof(x) <> 'null'
    returning path::text
 ) select string_agg(path, ',') from inserted

func remove_generated_html(_prof_ jsonb) returns jsonb
  SELECT this.merge(_prof_, '{"text":{"status":"generated","div":"<div>too costy</div>"}}'::jsonb)

func! load_structuredefinition(_prof_ jsonb, _kind_ text) returns text
   INSERT INTO structuredefinition
   (logical_id, name, type, kind, base, content)
   SELECT id, name, type, _kind_, base, content FROM (
     SELECT _prof_#>>'{id}' as id,
            _prof_#>>'{name}' as name,
            _prof_#>>'{type}' as type,
            _prof_#>>'{base}' as base,
            this.remove_generated_html(_prof_) as content,
            this.load_elements(_prof_)
   ) _
   RETURNING logical_id

-- insert structuredefinitions from bundle into meta tables
func! load_bundle(bundle jsonb, _kind_ text) returns text[]
 SELECT array_agg(this.load_structuredefinition(x->'resource', _kind_))
   FROM jsonb_array_elements(bundle#>'{entry}') x
   WHERE x#>>'{resource,resourceType}' = 'StructureDefinition'

CREATE TABLE this.search_type_to_type AS
        SELECT 'date' as stp,  '{date,dateTime,instant,Period,Timing}'::text[] as tp
  UNION SELECT 'token' as stp, '{boolean,code,CodeableConcept,Coding,Identifier,oid,Resource,string,uri}'::text[] as tp
  UNION SELECT 'string' as stp, '{Address,Attachment,CodeableConcept,ContactPoint,HumanName,Period,Quantity,Ratio,Resource,SampledData,string,uri}'::text[] as tp
  UNION SELECT 'number' as stp, '{integer,decimal,Duration,Quantity}'::text[] as tp
  UNION SELECT 'reference' as stp, '{Reference}'::text[] as tp
  UNION SELECT 'quantity' as stp, '{Quantity}'::text[] as tp;

-- insead using recursive type resoultion
-- we just hadcode missed
CREATE TABLE this.hardcoded_complex_params (
  path text[],
  type text
);

INSERT INTO this.hardcoded_complex_params
(path, type) VALUES
('{ConceptMap,concept,map,product,concept}','uri'),
('{DiagnosticOrder,item,event,dateTime}'   ,'dataTime'),
('{DiagnosticOrder,item,event,status}'     ,'code'),
('{Patient,name,family}'                   ,'string'),
('{Patient,name,given}'                    ,'string'),
('{Provenance,period,end}'                 ,'dateTime'),
('{Provenance,period,start}'               ,'dataTime');

CREATE TABLE this.searchparameter (
  id text PRIMARY KEY,
  name text,
  base text, --resource text,
  xpath text,
  path text[],
  search_type text,
  is_primitive boolean,
  type text,
  content jsonb
);

-- TODO: truncate
func! load_searchparameters(bundle jsonb) returns text[]
   with params as (
     SELECT x#>>'{resource,id}' as id,
            x#>>'{resource,name}' as name,
            x#>>'{resource,base}' as base,
            x#>>'{resource,xpath}' as xpath,
            regexp_split_to_array(replace(x#>>'{resource,xpath}','f:' ,'') , '/') as path,
            x#>>'{resource,type}' as search_type,
            x->'resource' as content
       FROM jsonb_array_elements(bundle#>'{entry}') x
      WHERE x#>>'{resource,resourceType}' = 'SearchParameter'
   ),
   -- add type information from structuredefinition_elements
   extended_params as (
    SELECT x.id, x.name, x.base, x.xpath, x.path, x.search_type, x.content,
      unnest(COALESCE(e.type, ARRAY[hp.type]::text[])) as type
      FROM params x
      LEFT JOIN structuredefinition_elements e
      ON e.path = x.path
      LEFT JOIN this.hardcoded_complex_params hp
      ON hp.path = x.path
      WHERE array_length(x.path,1) > 1
   ),
   inserted as (
     INSERT INTO searchparameter
     (logical_id, name, base, xpath, search_type, type, content, path, is_primitive)
     SELECT id, name, base, xpath, search_type, type, content,
       CASE WHEN this._last(path) ilike '%[x]' THEN
         this._butlast(path) || (replace(this._last(path),'[x]','') || type)::text
       ELSE
         path
       END as path,
       substr(type, 1,1)=lower(substr(type, 1,1)) as is_primitive
       from  extended_params
     RETURNING logical_id
   )
   SELECT array_agg(x.logical_id) FROM inserted x

\set datatypes `cat fhir/profiles-types.json`
select array_length(this.load_bundle(:'datatypes', 'datatype'), 1);

\set profs `cat fhir/profiles-resources.json`
SELECT array_length(this.load_bundle(:'profs', 'resource'),1);

-- mark installed
UPDATE structuredefinition
  SET installed = true
WHERE logical_id in ('StructureDefinition', 'SearchParameter', 'Resource');

\set searchp `cat fhir/search-parameters.json`
select array_length(this.load_searchparameters(:'searchp'), 1);
