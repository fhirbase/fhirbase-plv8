-- #import ../gen.sql
-- #import ./resources.sql

func! generate_base_tables() returns text
  --genarate base tables
  SELECT gen._eval(
    gen._tpl($SQL$
      SET client_min_messages=WARNING;
      CREATE EXTENSION IF NOT EXISTS pgcrypto;
      CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for ilike optimisation in search

      CREATE TABLE IF NOT EXISTS resource (
        version_id text,
        logical_id text,
        resource_type text,
        updated TIMESTAMP WITH TIME ZONE,
        published  TIMESTAMP WITH TIME ZONE,
        category jsonb,
        content jsonb
      );

      CREATE TABLE IF NOT EXISTS resource_history (
        version_id text,
        logical_id text,
        resource_type text,
        updated TIMESTAMP WITH TIME ZONE,
        published  TIMESTAMP WITH TIME ZONE,
        category jsonb,
        content jsonb
      );
      SET client_min_messages=INFO;
   $SQL$,
   'ns', 'TODO')
  )


SELECT this.generate_base_tables();


func! generate_tables(resources text[]) returns text
  --genarate all tables
  SELECT
  count(
  gen._eval(
    gen._tpl($SQL$
      SET client_min_messages to 'panic';
      --SELECT generate_base_tables('{{ns}}');

      CREATE TABLE "{{tbl_name}}" () INHERITS (resource);

      ALTER TABLE "{{tbl_name}}"
        ADD PRIMARY KEY (logical_id),
        ALTER COLUMN updated SET NOT NULL,
        ALTER COLUMN updated SET DEFAULT CURRENT_TIMESTAMP,
        ALTER COLUMN published SET NOT NULL,
        ALTER COLUMN published SET DEFAULT CURRENT_TIMESTAMP,
        ALTER COLUMN content SET NOT NULL,
        ALTER COLUMN resource_type SET DEFAULT '{{resource_type}}';


      -- this index speedup search joins (cause uuid are casted to texts)
      CREATE UNIQUE INDEX {{tbl_name}}_logical_id_as_text_idx
        ON "{{tbl_name}}" (CAST(logical_id AS text));

      CREATE INDEX {{tbl_name}}_full_text_idx
        ON "{{tbl_name}}" USING gin(to_tsvector('english', content::text));

      CREATE TABLE "{{tbl_name}}_history" () INHERITS (resource_history);

      ALTER TABLE "{{tbl_name}}_history"
        ADD PRIMARY KEY (version_id),
        ALTER COLUMN updated SET NOT NULL,
        ALTER COLUMN updated SET DEFAULT CURRENT_TIMESTAMP,
        ALTER COLUMN published SET NOT NULL,
        ALTER COLUMN published SET DEFAULT CURRENT_TIMESTAMP,
        ALTER COLUMN content SET NOT NULL,
        ALTER COLUMN resource_type SET DEFAULT '{{resource_type}}';

    $SQL$,
    'ns', 'TODO',
    'tbl_name', lower(path[1]),
    'resource_type', path[1])))::text
  FROM resources.resource_elements
  WHERE array_length(path,1) = 1
    AND (resources IS NULL OR resources @> ARRAY[path[1]::text]);

func! generate_tables() returns text
   SELECT this.generate_tables(null)
