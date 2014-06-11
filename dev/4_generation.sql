--db:fhirb
--{{{
SELECT
count(
eval_ddl(
  eval_template($SQL$

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

    CREATE TABLE "{{tbl_name}}_search_token" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar,
      namespace varchar,
      code varchar,
      text varchar
      -- ts_value ts_vector
    );

    CREATE TABLE "{{tbl_name}}_search_date" (
    _id SERIAL PRIMARY KEY,
    resource_id uuid references "{{tbl_name}}"(logical_id),
    param varchar,
    "start" timestamptz,
    "end" timestamptz
    );
  $SQL$,
  'tbl_name', lower(path[1]))))
FROM fhir.resource_elements
WHERE array_length(path,1) = 1;
--}}}
