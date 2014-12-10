--db:fhirb
--{{{
DROP TABLE IF EXISTS fhir.resource_elements CASCADE;
CREATE TABLE fhir.resource_elements (
  version varchar,
  path varchar[],
  min varchar,
  max varchar,
  type varchar[],
  ref_type varchar[],
  PRIMARY KEY(path)
);

DROP TABLE IF EXISTS fhir.resource_search_params CASCADE;
CREATE TABLE fhir.resource_search_params (
  _id SERIAL  PRIMARY KEY,
  path varchar[],
  name varchar,
  version varchar,
  type varchar,
  documentation text
);

CREATE OR REPLACE
FUNCTION xattr(pth varchar, x xml) returns varchar
AS $$
BEGIN
  RETURN unnest(xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']])) limit 1;
END
$$ language plpgsql;

CREATE OR REPLACE FUNCTION
profile_to_resource_type(profiles varchar[])
RETURNS varchar[] LANGUAGE sql AS $$
  SELECT array_agg(replace("unnest", 'http://hl7.org/fhir/profiles/', ''))::varchar[]
  FROM unnest(profiles);
$$;

CREATE OR REPLACE
FUNCTION fpath(pth varchar, x xml) returns xml[]
  as $$
  BEGIN
    return xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']]);
  END
$$ language plpgsql IMMUTABLE;

CREATE or REPLACE
FUNCTION xarrattr(pth varchar, x xml) returns varchar[]
  as $$
  BEGIN
    RETURN array(select unnest(fpath(pth, x))::varchar);
  END
$$ language plpgsql;

\set fhir `cat profiles-resources.xml`

INSERT INTO fhir.resource_elements
 (version, path, min, max, type, ref_type)
select
    '0.12' as version,
    regexp_split_to_array(xattr('./path/@value', el), '\.') as path,
    xattr('./definition/min/@value', el) as min,
    xattr('./definition/max/@value', el) as max,
    xarrattr('./definition/type/code/@value', el) as type,
    profile_to_resource_type(xarrattr('./definition/type/profile/@value', el)) as ref_type
  FROM (
    SELECT unnest(fpath('//fh:structure/fh:element', :'fhir')) as el
  ) els
;

INSERT INTO fhir.resource_search_params
 (version, path, name, type, documentation)
select
    '0.12' as version,
    coalesce(
      regexp_split_to_array(
        replace(
          xattr('./xpath/@value', el)
          ,'f:' ,'')
        , '/')
      ,ARRAY[res]) as path,
    xattr('./name/@value', el) as type,
    xattr('./type/@value', el) as type,
    xattr('./documentation/@value', el) as documentation
  FROM (
    SELECT
      xattr('./type/@value', st) as res,
      unnest(xpath('./searchParam', st)) as el
      FROM (
        SELECT unnest(fpath('//fh:structure', :'fhir')) as st
      ) st
  ) els
;

DROP TABLE IF EXISTS fhir.search_type_to_type CASCADE;
CREATE TABLE fhir.search_type_to_type AS
        SELECT 'date' as stp,  '{date,dateTime,instant,Period,Schedule}'::varchar[] as tp
  UNION SELECT 'token' as stp, '{boolean,code,CodeableConcept,Coding,Identifier,oid,Resource,string,uri}'::varchar[] as tp
  UNION SELECT 'string' as stp, '{Address,Attachment,CodeableConcept,Contact,HumanName,Period,Quantity,Ratio,Resource,SampledData,string,uri}'::varchar[] as tp
  UNION SELECT 'number' as stp, '{integer,decimal,Duration,Quantity}'::varchar[] as tp
  UNION SELECT 'reference' as stp, '{ResourceReference}'::varchar[] as tp
  UNION SELECT 'quantity' as stp, '{Quantity}'::varchar[] as tp;

-- insead using recursive type resoultion
-- we just hadcode missed
DROP TABLE IF EXISTS fhir.hardcoded_complex_params;
CREATE TABLE fhir.hardcoded_complex_params (
  path varchar[],
  type varchar
);
INSERT INTO fhir.hardcoded_complex_params
(path, type) VALUES
('{ConceptMap,concept,map,product,concept}','uri'),
('{DiagnosticOrder,item,event,dateTime}'   ,'dataTime'),
('{DiagnosticOrder,item,event,status}'     ,'code'),
('{Patient,name,family}'                   ,'string'),
('{Patient,name,given}'                    ,'string'),
('{Provenance,period,end}'                 ,'dateTime'),
('{Provenance,period,start}'               ,'dataTime');

SELECT assert_eq(0::bigint,
  (SELECT count(*)
    FROM fhir.resource_search_params p
    LEFT JOIN fhir.resource_elements e
    ON e.path = p.path
    LEFT JOIN fhir.hardcoded_complex_params hp
    ON hp.path = p.path
    WHERE (e.path IS NULL AND hp.path IS NULL)),
  'All cases covered');


-- TODO: fix lost params
DROP TABLE IF EXISTS fhir.resource_indexables;

CREATE TABLE fhir.resource_indexables (
  param_name text,
  resource_type text,
  path varchar[],
  search_type text,
  type text,
  is_primitive boolean
);

INSERT INTO fhir.resource_indexables
(param_name, resource_type, path, search_type, type, is_primitive)
SELECT
param_name, resource_type, path, search_type, type, is_primitive
FROM (
  SELECT  x.name as param_name,
          x.path[1] as resource_type,
          CASE WHEN _last(x.path) ilike '%[x]' THEN
            _butlast(x.path) || (replace(_last(x.path),'[x]','') || x.type)::varchar
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
           unnest(COALESCE(e.type, ARRAY[hp.type]::varchar[])) as type
    FROM fhir.resource_search_params p
    LEFT JOIN fhir.resource_elements e
    ON e.path = p.path
    LEFT JOIN fhir.hardcoded_complex_params hp
    ON hp.path = p.path
    WHERE array_length(p.path,1) > 1
  ) x
  JOIN fhir.search_type_to_type tt
  ON tt.stp = x.search_type
  AND x.type = ANY(tt.tp)
) _
GROUP BY param_name, resource_type, path, search_type, type, is_primitive;


-- here we insert metainformation for search by _id
-- just for unification of search query generation
INSERT INTO fhir.resource_indexables
(param_name, resource_type, path, search_type, type, is_primitive)
SELECT
'_id' as param_name
,resource_type as resource_type
,ARRAY[resource_type,'_id'] as path
,'identifier' as search_type
,'uuid' as type
, true as primitive
FROM fhir.resource_indexables
GROUP BY resource_type;

CREATE INDEX ON fhir.resource_indexables (resource_type, param_name, search_type);
--}}}
