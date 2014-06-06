--db:fhirb
--{{{
CREATE TABLE fhir.resource_elements (
  version varchar,
  path varchar[],
  min varchar,
  max varchar,
  type varchar[],
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

\set fhir `cat profiles-resources.xml`

INSERT INTO fhir.resource_elements
 (version, path, min, max, type)
select
    '0.12' as version,
    regexp_split_to_array(xattr('./path/@value', el), '\.') as path,
    xattr('./definition/min/@value', el) as min,
    xattr('./definition/max/@value', el) as max,
    xarrattr('./definition/type/code/@value', el) as type
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

-- expand polimorphic types
CREATE
VIEW fhir.polimorphic_expanded_resource_elements as (
  SELECT
    array_pop(path) || ARRAY[column_name(array_last(path), type)] as path,
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
      e.path || array_tail(t.path) as path,
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
);

CREATE OR REPLACE
VIEW fhir.resource_indexables AS (
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
);
--}}}

