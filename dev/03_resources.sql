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

--}}}
--{{{
-- expand polimorphic types
CREATE OR REPLACE
VIEW fhir.polimorphic_expanded_resource_elements as (
  SELECT
    _butlast(path) || ARRAY[column_name(_last(path), type)] as path,
    type,
    min,
    max
  FROM (
    SELECT
      path,
      CASE WHEN array_length(type, 1) is null
        THEN '_NestedResource_'
        ELSE unnest(type)
      END as type,
      min,
      max
    FROM fhir.resource_elements
  ) e
  WHERE type not in ('Extension', 'contained') OR type is null
);

-- elements recursively expanded with complex datatypes
CREATE OR REPLACE
VIEW fhir.expanded_resource_elements as (
  SELECT x.*
        ,CASE WHEN fpt.type IS NULL THEN
          false
        ELSE
          true
        END AS is_primitive
    FROM (
    SELECT
      e.path || _rest(t.path) as path,
      CASE WHEN array_length(t.path,1) = 1
        THEN e.min
        ELSE t.min
      END AS min,
      CASE WHEN array_length(t.path,1) = 1
        THEN e.max
        ELSE t.max
      END AS max,
      CASE WHEN array_length(t.path,1) = 1
        THEN e.type
        ELSE t.type
      END AS type
    FROM fhir.polimorphic_expanded_resource_elements e
    JOIN fhir.datatype_unified_elements t
    ON t.path[1] = e.type

    UNION ALL

    SELECT path, min, max, type
    FROM fhir.polimorphic_expanded_resource_elements e
  ) x
  LEFT JOIN fhir.primitive_types fpt
    ON fpt.type = x.type
  GROUP BY x.path, x.min, x.max, x.type, is_primitive
);

CREATE MATERIALIZED
VIEW fhir.resource_indexables AS (
WITH polimorphic_attrs_mapping AS (
        SELECT 'date' as stp,  '{date,dateTime,instant,Period,Schedule}'::varchar[] as tp
  UNION SELECT 'token' as stp, '{boolean,code,CodeableConcept,Coding,Identifier,oid,Resource,string,uri}'::varchar[] as tp
  UNION SELECT 'string' as stp, '{Address,Attachment,CodeableConcept,Contact,HumanName,Period,Quantity,Ratio,Resource,SampledData,string,uri}'::varchar[] as tp
  UNION SELECT 'quantity' as stp, '{Quantity}'::varchar[] as tp )
SELECT
  rsp.name as param_name
  ,rsp.path[1] as resource_type
  ,rsp.type as search_type
  ,ere.type as type
  ,ere.max
  ,ere.path
  ,ere.is_primitive
  FROM fhir.resource_search_params rsp
  JOIN fhir.expanded_resource_elements ere
    ON ere.path = rsp.path
       OR (_last(rsp.path) ilike '%[x]' -- handle polymorph
           AND _butlast(ere.path) = _butlast(rsp.path)
           AND position(
              replace(_last(rsp.path), '[x]','')
              in _last(ere.path)) = 1
           AND EXISTS (
             SELECT *
             FROM polimorphic_attrs_mapping pam
             WHERE pam.stp = rsp.type AND ere.type = ANY(pam.tp)))
);
--}}}
