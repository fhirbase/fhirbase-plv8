--db:fhirb
--{{{
drop schema if exists fhir cascade;
create schema fhir;

CREATE TABLE fhir.datatypes (
  version varchar,
  type varchar,
  kind varchar,
  extension varchar,
  restriction_base varchar,
  documentation text[],
  PRIMARY KEY(type)
);

CREATE TABLE fhir.datatype_elements (
  version varchar,
  datatype varchar references fhir.datatypes(type),
  name varchar,
  type varchar,
  min_occurs varchar,
  max_occurs varchar,
  documentation text,
  PRIMARY KEY(datatype, name)
);

CREATE TABLE fhir.datatype_enums (
  version varchar,
  datatype varchar references fhir.datatypes(type),
  value varchar,
  documentation text,
  PRIMARY KEY(datatype, value)
);

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

CREATE TABLE fhir.type_to_pg_type (
  type varchar,
  pg_type varchar
);

INSERT INTO fhir.type_to_pg_type (type, pg_type)
VALUES
('code', 'varchar'),
('date_time', 'timestamp'),
('string', 'varchar'),
('text', 'text'),
('uri', 'varchar'),
('datetime', 'timestamp'),
('instant', 'timestamp'),
('boolean', 'boolean'),
('base64_binary', 'bytea'),
('integer', 'integer'),
('decimal', 'decimal'),
('sampled_data_data_type', 'text'),
('date', 'date'),
('id', 'varchar'),
('oid', 'varchar');

\set fhir `cat profiles-resources.xml`
\set datatypes `cat fhir-base.xsd`

CREATE or REPLACE
FUNCTION xattr(pth varchar, x xml) returns varchar
  as $$
  BEGIN
    return  unnest(xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']])) limit 1;
  END
$$ language plpgsql;

-- HACK: see http://joelonsql.com/2013/05/13/xml-madness/
-- problems with namespaces
CREATE OR REPLACE
FUNCTION xspath(pth varchar, x xml) returns xml[]
  as $$
  BEGIN
    return  xpath('/xml' || pth, xml('<xml xmlns:xs="xs">' || x || '</xml>'), ARRAY[ARRAY['xs','xs']]);
  END
$$ language plpgsql IMMUTABLE;

CREATE OR REPLACE
FUNCTION xsattr(pth varchar, x xml) returns varchar
  as $$
  BEGIN
    return  unnest(xspath( pth,x)) limit 1;
  END
$$ language plpgsql IMMUTABLE;


CREATE OR REPLACE
FUNCTION fpath(pth varchar, x xml) returns xml[]
  as $$
  BEGIN
    return xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']]);
  END
$$ language plpgsql IMMUTABLE;

create OR replace
function xarrattr(pth varchar, x xml) returns varchar[]
  as $$
  BEGIN
    RETURN array(select unnest(fpath(pth, x))::varchar);
  END
$$ language plpgsql;

INSERT INTO fhir.datatypes (version, type)
(
  select
    '0.12' as version,
    xsattr('/xs:simpleType/@name', st) as type
    FROM (
    SELECT unnest(xpath('/xs:schema/xs:simpleType', :'datatypes',
       ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
  ) simple_types
  UNION
  select
    '0.12' as version,
    xsattr('/xs:complexType/@name', st) as type
    FROM (
    SELECT unnest(xpath('/xs:schema/xs:complexType', :'datatypes',
       ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
  ) simple_types
);

INSERT INTO fhir.datatype_enums (version, datatype, value)
SELECT
 '0.12' as version,
 datatype,
 xsattr('/xs:enumeration/@value', enum) as value
FROM
  (select
      xsattr('/xs:simpleType/@name', st) as datatype,
      unnest(xspath('/xs:simpleType/xs:restriction/xs:enumeration', st)) as enum
      FROM (SELECT unnest(xpath('/xs:schema/xs:simpleType', :'datatypes',
             ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
      ) n1
  ) n2;


INSERT INTO fhir.datatype_elements
(version, datatype, name, type, min_occurs, max_occurs)
SELECT
  '0.12' as version,
  datatype,
  coalesce(
    xsattr('/xs:element/@name', el),
    (string_to_array(xsattr('/xs:element/@ref', el),':'))[2]
  ) as name,
  coalesce(
    xsattr('/xs:element/@type', el),
    'text'
  ) as type,
  xsattr('/xs:element/@minOccurs', el) as min_occurs,
  xsattr('/xs:element/@maxOccurs', el) as max_occurs
FROM (
  SELECT
    xsattr('/xs:complexType/@name', st) as datatype,
    unnest(xspath('/xs:complexType/xs:complexContent/xs:extension/xs:sequence/xs:element', st)) as el
    FROM (
    SELECT unnest(xpath('/xs:schema/xs:complexType', :'datatypes',
       ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
  ) n1
) n2;

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
          ,'f:'
          ,'')
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

CREATE VIEW fhir.enums AS (
  SELECT  replace(datatype, '-list','')
      AS  enum
          ,array_agg(value)
      AS  options
    FROM  fhir.datatype_enums
GROUP BY  replace(datatype, '-list','')
);

CREATE VIEW fhir.primitive_types as (
  SELECT type
         ,pg_type
    FROM fhir.type_to_pg_type
   UNION SELECT enum, 'fhir."' || enum  || '"'
    FROM fhir.enums
);

CREATE VIEW fhir._datatype_unified_elements AS (
  SELECT ARRAY[datatype, name]
      AS path
         ,type
         ,min_occurs
      AS min
         ,CASE when max_occurs = 'unbounded'
           THEN '*'
           ELSE max_occurs
          END
      AS max
    FROM fhir.datatype_elements
   WHERE datatype <> 'Resource'
);

CREATE VIEW fhir.datatype_unified_elements as (
  WITH RECURSIVE tree(
    path
    ,type
    ,min
    ,max
  ) AS (
    SELECT r.* FROM fhir._datatype_unified_elements r
    UNION
    SELECT t.path || ARRAY[array_last(r.path)] as path,
           r.type as type,
           t.min as min,
           t.max as max
      FROM fhir._datatype_unified_elements r
      JOIN tree t on t.type = r.path[1]
  )
  SELECT * FROM tree t LIMIT 1000
);

CREATE VIEW fhir.unified_complex_datatype AS (
  SELECT   ue.path as path
           ,coalesce(tp.type, ue.path[1]) as type, tp.min, tp.max
     FROM  (
              SELECT array_pop(path)
                  AS path
                FROM fhir.datatype_unified_elements
            GROUP BY array_pop(path)
           )
       AS  ue
LEFT JOIN fhir.datatype_unified_elements tp
       ON tp.path = ue.path
);


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

-- get all elements wich have a children
-- all parent path is coumpound (teorema Bodnarchuka)
/* CREATE */
/* VIEW fhir.compound_resource_elements as ( */
/*   SELECT a.* */
/*          ,ere.min */
/*          ,ere.max */
/*     FROM ( */
/*             SELECT DISTINCT */
/*               array_pop(path) as path */
/*             FROM fhir.polimorphic_expanded_resource_elements */
/*             WHERE array_length(path,1) > 1 */
/*          ) a */
/*     LEFT JOIN fhir.polimorphic_expanded_resource_elements ere */
/*     ON ere.path = a.path */
/* ); */

-- elements recursively expanded with complex datatypes
CREATE
VIEW fhir.expanded_resource_elements as (
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
);
--}}}
