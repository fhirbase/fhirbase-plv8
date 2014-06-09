--db:fhirb
--{{{

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP FUNCTION IF EXISTS insert_resource(jsonb);

CREATE OR REPLACE FUNCTION
insert_resource(_rsrs jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
res_type varchar;
id uuid := gen_random_uuid();
published timestamptz :=  CURRENT_TIMESTAMP;
idx jsonb;
/* rec RECORD; */
BEGIN
  res_type := lower(_rsrs->>'resourceType');

  EXECUTE
    eval_template($SQL$
      INSERT INTO "{{tbl}}"
      (logical_id, version_id, published, last_modified_date, data)
      VALUES
      ($1, $2, $3, $4, $5)
    $SQL$, 'tbl', res_type)
  USING id, id, published, published, _rsrs;

  -- indexing strings
  FOR idx IN
    SELECT unnest(index_string_resource(_rsrs))
  LOOP
    --RAISE NOTICE 'idx %', idx;
    EXECUTE
      eval_template($SQL$
        INSERT INTO "{{tbl}}_search_string"
        (resource_id, param, value)
        SELECT $1,$2, jsonb_array_elements_text($3)
      $SQL$, 'tbl', res_type)
    USING id, idx->>'param', idx->'value';
  END LOOP;

  -- indexing tokens
  FOR idx IN
    SELECT unnest(index_token_resource(_rsrs))
    UNION
    SELECT json_build_object('param', '_id', 'code', id, 'text', id)::jsonb
  LOOP
    --RAISE NOTICE 'idx %', idx;
    EXECUTE
      eval_template($SQL$
        INSERT INTO "{{tbl}}_search_token"
        (resource_id, param, namespace, code, text)
        SELECT $1, $2->>'param', $2->>'system', $2->>'code', $2->>'text'
      $SQL$, 'tbl', res_type)
    USING id, idx;
  END LOOP;
  RETURN id;
END
$$;

CREATE OR REPLACE FUNCTION
update_resource(_rsrs jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
BEGIN
  /* move old version to history */
  /* remove res old indexes */

  /* insert resource with fixed id*/
  /* create new indexes */
END
$$;

CREATE OR REPLACE FUNCTION
delete_resource(_rsrs jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
BEGIN
  /* move old version to history */
  /* remove res old indexes */
  /* create new indexes */
END
$$;
--}}}
