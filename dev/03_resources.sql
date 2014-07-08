--db:fhirb
--{{{
CREATE TABLE fhir.resource_elements (
  version varchar,
  path varchar[],
  min varchar,
  max varchar,
  type varchar[],
  ref_type varchar[],
  PRIMARY KEY(path)
);

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
  UNION SELECT 'quantity' as stp, '{Quantity}'::varchar[] as tp;



-- TODO: fix lossed params
DROP MATERIALIZED VIEW IF EXISTS fhir.resource_indexables;
CREATE MATERIALIZED
VIEW fhir.resource_indexables AS (
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
         unnest(e.type) as type
  FROM fhir.resource_search_params p
  LEFT JOIN fhir.resource_elements e
  ON e.path = p.path
) x
JOIN fhir.search_type_to_type tt
ON tt.stp = x.search_type
AND x.type = ANY(tt.tp));
--}}}
