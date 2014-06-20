--db:fhirb
--{{{

SET client_min_messages=WARNING;
CREATE TABLE resource (
    version_id uuid,
    logical_id uuid,
    resource_type varchar,
    last_modified_date TIMESTAMP WITH TIME ZONE,
    published  TIMESTAMP WITH TIME ZONE,
    data jsonb
);

CREATE TABLE tag (
  id uuid,
  resource_id uuid,
  resource_version_id uuid,
  resource_type varchar,
  scheme varchar,
  term varchar,
  label text
);

SELECT
count(
eval_ddl(
  eval_template($SQL$
    CREATE TABLE "{{tbl_name}}" (
      version_id uuid PRIMARY KEY,
      logical_id uuid UNIQUE,
      resource_type varchar DEFAULT '{{tbl_name}}',
      last_modified_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published  TIMESTAMP WITH TIME ZONE NOT NULL,
      data jsonb NOT NULL
    ) INHERITS (resource);

    CREATE TABLE {{tbl_name}}_tag (
      id uuid PRIMARY KEY,
      resource_id uuid REFERENCES "{{tbl_name}}" (logical_id),
      resource_version_id uuid NOT NULL,
      resource_type varchar DEFAULT '{{tbl_name}}',
      scheme varchar NOT NULL,
      term varchar NOT NULL,
      label text
    ) INHERITS (tag);

    CREATE TABLE "{{tbl_name}}_history" (
      version_id uuid PRIMARY KEY,
      logical_id uuid NOT NULL,
      resource_type varchar DEFAULT '{{tbl_name}}',
      last_modified_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published  TIMESTAMP WITH TIME ZONE NOT NULL,
      data jsonb NOT NULL
    );

    CREATE TABLE {{tbl_name}}_history_tag (
      id uuid PRIMARY KEY,
      resource_id uuid NOT NULL,
      resource_version_id uuid REFERENCES "{{tbl_name}}_history" (version_id),
      resource_type varchar DEFAULT '{{tbl_name}}',
      scheme varchar NOT NULL,
      term varchar NOT NULL,
      label text
    ) INHERITS (tag);

    CREATE TABLE "{{tbl_name}}_search_string" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar NOT NULL,
      value varchar
      -- ts_value ts_vector
    );

    CREATE TABLE "{{tbl_name}}_search_token" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar NOT NULL,
      namespace varchar,
      code varchar,
      text varchar
      -- ts_value ts_vector
    );

    CREATE TABLE "{{tbl_name}}_search_date" (
    _id SERIAL PRIMARY KEY,
    resource_id uuid references "{{tbl_name}}"(logical_id),
    param varchar NOT NULL,
    "start" timestamptz,
    "end" timestamptz
    );

    -- references
    CREATE TABLE "{{tbl_name}}_search_reference" (
    _id SERIAL PRIMARY KEY,
    resource_id uuid references "{{tbl_name}}"(logical_id),
    param varchar NOT NULL,
    resource_type varchar NOT NULL,
    logical_id varchar NOT NULL,
    url varchar
    );

    --quantity
    CREATE TABLE "{{tbl_name}}_search_quantity" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar,
      value decimal,
      comparator varchar,
      units varchar,
      system varchar,
      code varchar
    );

    -- index for search includes
    CREATE TABLE "{{tbl_name}}_references" (
      _id SERIAL PRIMARY KEY,
      logical_id uuid NOT NULL,
      path varchar NOT NULL,
      reference_type varchar NOT NULL,
      reference_id uuid NOT NULL
    );
  $SQL$,
  'tbl_name', lower(path[1]))))
FROM fhir.resource_elements
WHERE array_length(path,1) = 1;

SET client_min_messages=INFO;
--}}}
