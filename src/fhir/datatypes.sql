-- #import ../xml_utils.sql

CREATE TABLE this.datatypes (
--- store list of datatypes
  version text,
  type text,
  kind text,
  extension text,
  restriction_base text,
  documentation text[],
  PRIMARY KEY(type)
);

CREATE TABLE this.datatype_elements (
  --- store relations between complex datatypes
  version text,
  datatype text references this.datatypes(type),
  name text,
  type text,
  min_occurs text,
  max_occurs text,
  documentation text,
  PRIMARY KEY(datatype, name)
);

CREATE TABLE this.datatype_enums (
  --- store enumerated values for enum datatypes
  version text,
  datatype text references this.datatypes(type),
  value text,
  documentation text,
  PRIMARY KEY(datatype, value)
);

-- Load metadata from xsd file
\set datatypes `cat src/fhir/fhir-base.xsd`

INSERT INTO this.datatypes (version, type)
(
  SELECT '0.4.0' as version,
         xml_utils.xsattr('/xs:simpleType/@name', st) as type
   FROM (
          SELECT unnest(xpath('/xs:schema/xs:simpleType', :'datatypes',
             ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
        ) simple_types
  UNION
  SELECT '0.4.0' as version,
          xml_utils.xsattr('/xs:complexType/@name', st) as type
        FROM (
          SELECT unnest(xpath('/xs:schema/xs:complexType', :'datatypes',
             ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
        ) simple_types
);


INSERT INTO this.datatype_enums (version, datatype, value)
SELECT '0.4.0' as version,
       datatype,
       xml_utils.xsattr('/xs:enumeration/@value', enum) as value
  FROM (SELECT xml_utils.xsattr('/xs:simpleType/@name', st) as datatype,
               unnest(xml_utils.xspath('/xs:simpleType/xs:restriction/xs:enumeration', st)) as enum
          FROM (SELECT unnest(xpath('/xs:schema/xs:simpleType', :'datatypes',
                       ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
          ) n1
      ) n2;


INSERT INTO this.datatype_elements
(version, datatype, name, type, min_occurs, max_occurs)
SELECT '0.4.0' as version,
        datatype,
        coalesce(
          xml_utils.xsattr('/xs:element/@name', el),
          (string_to_array(xml_utils.xsattr('/xs:element/@ref', el),':'))[2]
        ) as name,
        coalesce(
          xml_utils.xsattr('/xs:element/@type', el),
          'text'
        ) as type,
        xml_utils.xsattr('/xs:element/@minOccurs', el) as min_occurs,
        xml_utils.xsattr('/xs:element/@maxOccurs', el) as max_occurs
FROM ( SELECT xml_utils.xsattr('/xs:complexType/@name', st) as datatype,
              unnest(xml_utils.xspath('/xs:complexType/xs:complexContent/xs:extension/xs:sequence/xs:element', st)) as el
        FROM ( SELECT unnest(xpath('/xs:schema/xs:complexType', :'datatypes',
               ARRAY[ARRAY['xs', 'http://www.w3.org/2001/XMLSchema']])) st
    ) n1
  ) n2;

CREATE VIEW this.enums AS (
  SELECT  replace(datatype, '-list','') AS  enum
          ,array_agg(value) AS  options
    FROM  this.datatype_enums
GROUP BY  replace(datatype, '-list','')
);
