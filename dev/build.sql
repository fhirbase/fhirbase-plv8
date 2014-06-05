--db:fhirb
--{{{
\l
--}}}
--{{{
drop schema if exists fhir cascade;
create schema fhir;
-- FIXME: foreign keys and indexes

CREATE OR REPLACE FUNCTION
eval_template(_tpl text, variadic _bindings varchar[])
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
result text := _tpl;
BEGIN
  FOR i IN 1..(array_upper(_bindings, 1)/2) LOOP
    result := replace(result, '{{' || _bindings[i*2 - 1] || '}}', _bindings[i*2]);
  END LOOP;
  RETURN result;
END
$$;

CREATE OR REPLACE FUNCTION eval_ddl(str text)
RETURNS text AS
$BODY$
  begin
    EXECUTE str;
    RETURN str;
  end;
$BODY$
LANGUAGE plpgsql VOLATILE;

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

SELECT
eval_ddl(
  eval_template($SQL$
    DROP TABLE IF EXISTS "{{tbl_name}}" CASCADE;
    DROP TABLE IF EXISTS "{{tbl_name}}_history" CASCADE;
    DROP TABLE IF EXISTS "{{tbl_name}}_search_string" CASCADE;
    CREATE TABLE "{{tbl_name}}" (
      version_id uuid PRIMARY KEY,
      logical_id uuid UNIQUE,
      last_modified_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published  TIMESTAMP WITH TIME ZONE NOT NULL,
      data jsonb NOT NULL
    );
    CREATE TABLE "{{tbl_name}}_history" (
      version_id uuid PRIMARY KEY,
      logical_id uuid NOT NULL,
      last_modified_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published  TIMESTAMP WITH TIME ZONE NOT NULL,
      data jsonb NOT NULL
    );
    CREATE TABLE "{{tbl_name}}_search_string" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar,
      value varchar
      -- ts_value ts_vector
    );
  $SQL$,
  'tbl_name', lower(path[1]))
)
FROM fhir.resource_elements
WHERE array_length(path,1) = 1;
--}}}
