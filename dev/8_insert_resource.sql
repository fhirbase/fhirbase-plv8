--db:fhirb
--{{{

--TODO: handle publish date

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION
insert_resource(_rsrs jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  id uuid := gen_random_uuid();
BEGIN
  RETURN insert_resource(id, _rsrs);
END
$$;

CREATE OR REPLACE FUNCTION
insert_resource(id uuid, _rsrs jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  res_type varchar;
  published timestamptz :=  CURRENT_TIMESTAMP;
  vid uuid := gen_random_uuid();
BEGIN
  res_type := lower(_rsrs->>'resourceType');

  EXECUTE
    eval_template($SQL$
      INSERT INTO "{{tbl}}"
      (logical_id, version_id, published, last_modified_date, data)
      VALUES
      ($1, $2, $3, $4, $5)
    $SQL$, 'tbl', res_type)
  USING id, vid, published, published, _rsrs;

  PERFORM index_resource(id, res_type, _rsrs);

  RETURN id;
END
$$;

CREATE OR REPLACE FUNCTION
index_resource(id uuid, res_type varchar)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  rec RECORD;
  rsrs jsonb;
BEGIN
  EXECUTE
    eval_template($SQL$
      SELECT data FROM "{{tbl}}"
        WHERE logical_id = $1
        LIMIT 1
    $SQL$, 'tbl', res_type)
  INTO rsrs USING id;
  RETURN index_resource(id, res_type, rsrs);
END
$$;

CREATE OR REPLACE FUNCTION
index_resource(id uuid, res_type varchar, _rsrs jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  rec RECORD;
  idx jsonb;
BEGIN
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

  -- indexing dates
  /* FOR idx IN */
  /* SELECT unnest(index_date_resource(_rsrs)) */
  /* LOOP */
  /* --RAISE NOTICE 'idx %', idx; */
  /* EXECUTE */
  /* eval_template($SQL$ */
  /* INSERT INTO "{{tbl}}_search_date" */
  /* (resource_id, param, "start", "end") */
  /* SELECT $1, $2->>'param', $2->>'start', $2->>'end' */
  /* $SQL$, 'tbl', res_type) */
  /* USING id, idx; */
  /* END LOOP; */

  -- indexing quantity
  FOR idx IN
  SELECT unnest(index_quantity_resource(_rsrs))
  LOOP
    EXECUTE
      eval_template($SQL$
        INSERT INTO "{{tbl}}_search_quantity"
        (resource_id, param, value, comparator, units, system, code)
        SELECT $1, $2->>'param', ($2->>'value')::decimal, $2->>'comparator', $2->>'units', $2->>'system', $2->>'code'
      $SQL$, 'tbl', res_type)
    USING id, idx;
  END LOOP;

  RETURN id;
END
$$;

--DROP FUNCTION delete_resource(uuid);

CREATE OR REPLACE FUNCTION
delete_resource(id uuid, res_type varchar)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
BEGIN
  EXECUTE
    eval_template($SQL$
      INSERT INTO "{{tbl}}_history"
      SELECT * FROM {{tbl}}
      WHERE logical_id = $1;

      DELETE FROM "{{tbl}}_search_string" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_search_token" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}" WHERE logical_id = $1;
    $SQL$, 'tbl', lower(res_type))
  USING id;

  RETURN id;
END
$$;

-- TODO: implement by UPDATE
CREATE OR REPLACE FUNCTION
update_resource(id uuid, _rsrs jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  res_type varchar;
BEGIN
  res_type := lower(_rsrs->>'resourceType');
  PERFORM delete_resource(id, res_type);
  RETURN insert_resource(id, _rsrs);
END
$$;
--}}}
