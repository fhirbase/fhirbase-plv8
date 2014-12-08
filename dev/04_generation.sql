--db:fhirb
--{{{
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for ilike optimisation in search

SET client_min_messages=WARNING;
CREATE TABLE resource (
  version_id uuid,
  logical_id uuid,
  resource_type varchar,
  updated TIMESTAMP WITH TIME ZONE,
  published  TIMESTAMP WITH TIME ZONE,
  category jsonb,
  content jsonb
);

CREATE TABLE resource_history (
  version_id uuid,
  logical_id uuid,
  resource_type varchar,
  updated TIMESTAMP WITH TIME ZONE,
  published  TIMESTAMP WITH TIME ZONE,
  category jsonb,
  content jsonb
);

SELECT
count(
_eval(
  _tpl($SQL$
    CREATE TABLE "{{tbl_name}}" (
      logical_id uuid PRIMARY KEY default gen_random_uuid(),
      version_id uuid UNIQUE default gen_random_uuid(),
      resource_type varchar DEFAULT '{{resource_type}}',
      updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      content jsonb NOT NULL,
      category jsonb
    ) INHERITS (resource);

    -- this index speedup search joins (cause uuid are casted to varchars)
    CREATE UNIQUE INDEX {{tbl_name}}_logical_id_as_varchar_idx
    ON "{{tbl_name}}" (CAST(logical_id AS varchar));

    CREATE INDEX {{tbl_name}}_full_text_idx ON "{{tbl_name}}" USING gin(to_tsvector('english', content::text));

    CREATE TABLE "{{tbl_name}}_history" (
      version_id uuid PRIMARY KEY,
      logical_id uuid NOT NULL,
      resource_type varchar DEFAULT '{{resource_type}}',
      updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      content jsonb NOT NULL,
      category jsonb
    ) INHERITS (resource_history);
  $SQL$,
  'tbl_name', lower(path[1]),
  'resource_type', path[1])))
FROM fhir.resource_elements
WHERE array_length(path,1) = 1;

SET client_min_messages=INFO;
--}}}
