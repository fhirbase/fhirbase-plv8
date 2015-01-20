-- #import ../coll.sql

DROP TABLE IF EXISTS this.resource_elements CASCADE;
CREATE TABLE this.resource_elements (
  version text,
  path text[],
  min text,
  max text,
  type text[],
  ref_type text[],
  PRIMARY KEY(path)
);

DROP TABLE IF EXISTS this.resource_search_params CASCADE;
CREATE TABLE this.resource_search_params (
  _id SERIAL  PRIMARY KEY,
  resource text,
  path text[],
  name text,
  version text,
  type text,
  documentation text
);

func xattr(pth text, _x_ xml) returns text
  SELECT y::text
    FROM unnest(xpath(pth, _x_, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']])) y
    LIMIT 1

func profile_to_resource_type(_profiles_ text[]) RETURNS text[]
  SELECT array_agg(replace("unnest", 'http://hl7.org/fhir/Profile/', ''))::text[]
  FROM unnest(_profiles_);

func fpath(_pth_ text, _x_ xml) returns xml[]
  SELECT xpath(_pth_, _x_, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']])

func xarrattr(pth text, x xml) returns text[]
  SELECT array_agg(y::text)
    from unnest(this.fpath(pth, x)) y

\set fhir `cat src/fhir/profiles-resources.xml`

INSERT INTO this.resource_elements
 (version, path, min, max, type, ref_type)
select
    '0.4.0' as version,
    regexp_split_to_array(this.xattr('./path/@value', el), '\.') as path,
    this.xattr('./min/@value', el) as min,
    this.xattr('./max/@value', el) as max,
    this.xarrattr('./type/code/@value', el) as type,
    this.profile_to_resource_type(this.xarrattr('./type/profile/@value', el)) as ref_type
  FROM (
    SELECT unnest(this.fpath('//fh:resource/fh:Profile/fh:snapshot/fh:element', :'fhir')) as el
  ) els
;

\set fhirs `cat src/fhir/search-parameters.xml`

INSERT INTO this.resource_search_params
 (version, resource, path, name, type, documentation)
SELECT
  '0.4.0' as version,
  this.xattr('./base/@value', el) as resource,
  regexp_split_to_array(
           replace(
                this.xattr('./xpath/@value', el)
                ,'f:' ,'')
            , '/') as path,
  this.xattr('./name/@value', el) as name,
  this.xattr('./type/@value', el) as type,
  this.xattr('./description/@value', el) as documentation

FROM (
  SELECT unnest(this.fpath('//fh:SearchParameter', :'fhirs')) as el
) _
;

DROP TABLE IF EXISTS this.search_type_to_type CASCADE;
CREATE TABLE this.search_type_to_type AS
        SELECT 'date' as stp,  '{date,dateTime,instant,Period,Timing}'::text[] as tp
  UNION SELECT 'token' as stp, '{boolean,code,CodeableConcept,Coding,Identifier,oid,Resource,string,uri}'::text[] as tp
  UNION SELECT 'string' as stp, '{Address,Attachment,CodeableConcept,ContactPoint,HumanName,Period,Quantity,Ratio,Resource,SampledData,string,uri}'::text[] as tp
  UNION SELECT 'number' as stp, '{integer,decimal,Duration,Quantity}'::text[] as tp
  UNION SELECT 'reference' as stp, '{Reference}'::text[] as tp
  UNION SELECT 'quantity' as stp, '{Quantity}'::text[] as tp;

-- insead using recursive type resoultion
-- we just hadcode missed
DROP TABLE IF EXISTS this.hardcoded_complex_params CASCADE;
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


-- TODO: fix lost params
DROP TABLE IF EXISTS this.resource_indexables CASCADE;
CREATE TABLE this.resource_indexables (
  param_name text,
  resource_type text,
  path text[],
  search_type text,
  type text,
  is_primitive boolean
);

/* TODO: use CTE */
INSERT INTO this.resource_indexables
(param_name, resource_type, path, search_type, type, is_primitive)
SELECT
param_name, resource_type, path, search_type, type, is_primitive
FROM (
  SELECT  x.name as param_name,
          x.path[1] as resource_type,
          CASE WHEN coll._last(x.path) ilike '%[x]' THEN
            coll._butlast(x.path) || (replace(coll._last(x.path),'[x]','') || x.type)::text
          ELSE
            x.path
          END as path,
          x.search_type,
          x.type,
          substr(x.type, 1,1)=lower(substr(x.type, 1,1)) as is_primitive
  FROM (
    SELECT p.name,
           p.path,
           p.type as search_type,
           unnest(COALESCE(e.type, ARRAY[hp.type]::text[])) as type
    FROM this.resource_search_params p
    LEFT JOIN this.resource_elements e
    ON e.path = p.path
    LEFT JOIN this.hardcoded_complex_params hp
    ON hp.path = p.path
    WHERE array_length(p.path,1) > 1
  ) x
  JOIN this.search_type_to_type tt
  ON tt.stp = x.search_type
  AND x.type = ANY(tt.tp)
) _
GROUP BY param_name, resource_type, path, search_type, type, is_primitive;


-- here we insert metainformation for search by _id
-- just for unification of search query generation
INSERT INTO this.resource_indexables
(param_name, resource_type, path, search_type, type, is_primitive)
SELECT
  '_id' as param_name
  ,resource_type as resource_type
  ,ARRAY[resource_type,'_id'] as path
  ,'identifier' as search_type
  ,'uuid' as type
  , true as primitive
FROM this.resource_indexables
GROUP BY resource_type;


CREATE INDEX ON this.resource_indexables (resource_type, param_name, search_type);
