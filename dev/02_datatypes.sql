--db:fhirb
--{{{

--- load metadata about datatypes from xsd
--- into meta tables

drop schema if exists fhir cascade;
create schema fhir;

CREATE OR REPLACE
FUNCTION xspath(pth varchar, x xml) returns xml[]
--- @private
--- HACK: see http://joelonsql.com/2013/05/13/xml-madness/
--- problems with namespaces
AS $$
BEGIN
  return  xpath('/xml' || pth, xml('<xml xmlns:xs="xs">' || x || '</xml>'), ARRAY[ARRAY['xs','xs']]);
END
$$ language plpgsql IMMUTABLE;

CREATE OR REPLACE
FUNCTION xsattr(pth varchar, x xml) returns varchar
--- @private
AS $$
BEGIN
  RETURN unnest(xspath( pth,x)) limit 1;
END
$$ language plpgsql IMMUTABLE;

CREATE TABLE fhir.datatypes (
--- store list of datatypes
  version varchar,
  type varchar,
  kind varchar,
  extension varchar,
  restriction_base varchar,
  documentation text[],
  PRIMARY KEY(type)
);

CREATE TABLE fhir.datatype_elements (
  --- store relations between complex datatypes
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
  --- store enumerated values for enum datatypes
  version varchar,
  datatype varchar references fhir.datatypes(type),
  value varchar,
  documentation text,
  PRIMARY KEY(datatype, value)
);

-- Load metadata from xsd file
\set datatypes `cat fhir-base.xsd`

INSERT INTO fhir.datatypes (version, type)
(
  SELECT '0.12' as version,
         xsattr('/xs:simpleType/@name', st) as type
   FROM (
          SELECT unnest(xpath('/xs:schema/xs:simpleType', :'datatypes',
             ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
        ) simple_types
  UNION
  SELECT '0.12' as version,
          xsattr('/xs:complexType/@name', st) as type
        FROM (
          SELECT unnest(xpath('/xs:schema/xs:complexType', :'datatypes',
             ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
        ) simple_types
);


INSERT INTO fhir.datatype_enums (version, datatype, value)
SELECT '0.12' as version,
       datatype,
       xsattr('/xs:enumeration/@value', enum) as value
  FROM (SELECT xsattr('/xs:simpleType/@name', st) as datatype,
               unnest(xspath('/xs:simpleType/xs:restriction/xs:enumeration', st)) as enum
          FROM (SELECT unnest(xpath('/xs:schema/xs:simpleType', :'datatypes',
                       ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
          ) n1
      ) n2;


INSERT INTO fhir.datatype_elements
(version, datatype, name, type, min_occurs, max_occurs)
SELECT '0.12' as version,
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
FROM ( SELECT xsattr('/xs:complexType/@name', st) as datatype,
              unnest(xspath('/xs:complexType/xs:complexContent/xs:extension/xs:sequence/xs:element', st)) as el
        FROM ( SELECT unnest(xpath('/xs:schema/xs:complexType', :'datatypes',
               ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
    ) n1
  ) n2;

CREATE VIEW fhir.enums AS (
  SELECT  replace(datatype, '-list','') AS  enum
          ,array_agg(value) AS  options
    FROM  fhir.datatype_enums
GROUP BY  replace(datatype, '-list','')
);
--}}}
