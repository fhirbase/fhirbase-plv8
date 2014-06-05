--db:fhirb
--{{{
SELECT
count(
eval_ddl(
  eval_template($SQL$
    DROP TABLE IF EXISTS "{{tbl_name}}_search_string" CASCADE;
    DROP TABLE IF EXISTS "{{tbl_name}}_history" CASCADE;
    DROP TABLE IF EXISTS "{{tbl_name}}" CASCADE;

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
  'tbl_name', lower(path[1]))))
FROM fhir.resource_elements
WHERE array_length(path,1) = 1;

--}}}
--{{{

select * from fhir.expanded_resource_elements
where path[1]='Patient' and path[2]='address'
order by path
--}}}
