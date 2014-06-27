--db:fhirb
--{{{
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for ilike optimisation in search

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

CREATE TABLE history_tag (
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
      logical_id uuid PRIMARY KEY,
      version_id uuid UNIQUE,
      resource_type varchar DEFAULT '{{resource_type}}',
      last_modified_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published  TIMESTAMP WITH TIME ZONE NOT NULL,
      data jsonb NOT NULL
    ) INHERITS (resource);

    CREATE TABLE {{tbl_name}}_tag (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      resource_id uuid REFERENCES "{{tbl_name}}" (logical_id),
      resource_version_id uuid NOT NULL,
      resource_type varchar DEFAULT '{{resource_type}}',
      scheme varchar NOT NULL,
      term varchar NOT NULL,
      label text
    ) INHERITS (tag);

    -- tags on resource should be unique
    CREATE UNIQUE INDEX {{tbl_name}}_tag_on_version_id_and_term_and_scheme_idx
    ON {{tbl_name}}_tag (resource_id, resource_version_id, term, scheme);

    -- this one should be used on search joins
    CREATE INDEX {{tbl_name}}_tag_on_resource_id_and_scheme_idx
    ON {{tbl_name}}_tag (resource_id);

    CREATE TABLE {{tbl_name}}_sort (
      _id SERIAL PRIMARY KEY,
      resource_id uuid REFERENCES "{{tbl_name}}" (logical_id),
      param varchar NOT NULL,
      upper varchar NOT NULL,
      lower varchar NOT NULL
    );

    CREATE UNIQUE INDEX {{tbl_name}}_sort_uniq_on_param_idx
    ON {{tbl_name}}_sort (resource_id, param);

    CREATE INDEX {{tbl_name}}_sort_on_upper_idx
    ON {{tbl_name}}_sort (upper);

    CREATE INDEX {{tbl_name}}_sort_on_lower_idx
    ON {{tbl_name}}_sort (lower);

    CREATE TABLE "{{tbl_name}}_history" (
      version_id uuid PRIMARY KEY,
      logical_id uuid NOT NULL,
      resource_type varchar DEFAULT '{{resource_type}}',
      last_modified_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      published  TIMESTAMP WITH TIME ZONE NOT NULL,
      data jsonb NOT NULL
    );

    CREATE TABLE {{tbl_name}}_history_tag (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      resource_id uuid NOT NULL,
      resource_version_id uuid REFERENCES "{{tbl_name}}_history" (version_id),
      resource_type varchar DEFAULT '{{resource_type}}',
      scheme varchar NOT NULL,
      term varchar NOT NULL,
      label text
    ) INHERITS (history_tag);

    CREATE TABLE "{{tbl_name}}_search_string" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar NOT NULL,
      value varchar
      -- ts_value ts_vector
    );

    -- composite index for fast joins
    CREATE INDEX {{tbl_name}}_search_string_on_resource_id_and_param_idx
    ON {{tbl_name}}_search_string (resource_id, param);

    -- trigram index on value for partial match (name = 'Jim')
    CREATE INDEX {{tbl_name}}_search_string_on_value_trgm_idx
    ON {{tbl_name}}_search_string USING gist (value gist_trgm_ops);

    -- simple index on value for exact match (name:exact = 'Jim')
    CREATE INDEX {{tbl_name}}_search_string_on_value_idx
    ON {{tbl_name}}_search_string (value);

    CREATE TABLE "{{tbl_name}}_search_token" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar NOT NULL,
      namespace varchar,
      code varchar,
      text varchar
      -- ts_value ts_vector
    );

    -- index for join
    CREATE INDEX {{tbl_name}}_search_token_on_resource_id_and_param_idx
    ON {{tbl_name}}_search_token (resource_id, param);

    -- index for code:text modifier (gender:text = 'Male')
    CREATE INDEX {{tbl_name}}_search_token_on_text_idx
    ON {{tbl_name}}_search_token (text);

    CREATE INDEX {{tbl_name}}_search_token_on_code_and_namespace_idx
    ON {{tbl_name}}_search_token (code, namespace);

    CREATE TABLE "{{tbl_name}}_search_date" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar NOT NULL,
      "start" timestamptz,
      "end" timestamptz
    );

    -- index for join
    CREATE INDEX {{tbl_name}}_search_date_on_resource_id_and_param_idx
    ON {{tbl_name}}_search_date (resource_id, param);

    -- index for tstzrange(start, end) && tstzrange(...)
    CREATE INDEX {{tbl_name}}_search_date_on_start_end_range_gist_idx
    ON {{tbl_name}}_search_date USING GiST (tstzrange("start", "end"));

    -- references
    CREATE TABLE "{{tbl_name}}_search_reference" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid references "{{tbl_name}}"(logical_id),
      param varchar NOT NULL,
      resource_type varchar NOT NULL,
      logical_id varchar NOT NULL,
      url varchar
    );

    -- index for join
    CREATE INDEX {{tbl_name}}_search_reference_on_resource_id_and_param_idx
    ON {{tbl_name}}_search_reference (resource_id, param);

    -- most often used case for refrence searches
    CREATE INDEX {{tbl_name}}_search_reference_on_logical_id_and_resource_type_idx
    ON {{tbl_name}}_search_reference (logical_id, resource_type);

    CREATE INDEX {{tbl_name}}_search_reference_on_url_idx
    ON {{tbl_name}}_search_reference (url);

    -- quantity
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

    -- index for join
    CREATE INDEX {{tbl_name}}_search_quantity_on_resource_id_and_param_idx
    ON {{tbl_name}}_search_quantity (resource_id, param);

    CREATE INDEX {{tbl_name}}_search_quantity_on_value_idx
    ON {{tbl_name}}_search_quantity (value);

    -- TODO: maybe index on units?

    -- index for search includes
    CREATE TABLE "{{tbl_name}}_references" (
      _id SERIAL PRIMARY KEY,
      resource_id uuid NOT NULL,
      path varchar NOT NULL,
      reference_type varchar NOT NULL,
      logical_id varchar NOT NULL
    );

    -- index for join
    CREATE INDEX {{tbl_name}}_references_on_resource_id_idx
    ON {{tbl_name}}_references (resource_id);

    -- also used during join (will postgres use it?)
    CREATE INDEX {{tbl_name}}_references_on_path_idx
    ON {{tbl_name}}_references (path);
  $SQL$,
  'tbl_name', lower(path[1]),
  'resource_type', path[1])))
FROM fhir.resource_elements
WHERE array_length(path,1) = 1;

SET client_min_messages=INFO;
--}}}
