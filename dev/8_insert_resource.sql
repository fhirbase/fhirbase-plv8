--db:fhirb
--{{{

--TODO: handle publish date

CREATE OR REPLACE FUNCTION
insert_resource(_rsrs jsonb, _tags jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  id uuid := gen_random_uuid();
BEGIN
  RETURN insert_resource(id, _rsrs, _tags);
END
$$;

CREATE OR REPLACE FUNCTION
insert_resource(id uuid, _rsrs jsonb, _tags jsonb)
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

  PERFORM create_tags(id, vid, res_type, _tags);
  PERFORM index_resource(id, res_type, _rsrs);
  PERFORM denormalize_sort(id, res_type);

  RETURN id;
END
$$;

--private
CREATE OR REPLACE FUNCTION
denormalize_sort(_id uuid, res_type varchar)
RETURNS text
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE
    eval_template($SQL$
      INSERT INTO {{tbl}}_sort
      (resource_id, param, lower, upper)
      SELECT resource_id, param, value, value FROM {{tbl}}_search_string
       WHERE resource_id = $1
    $SQL$, 'tbl', res_type)
  USING _id;
  RETURN _id;
END
$$;


--private
CREATE OR REPLACE FUNCTION
create_tags(_id uuid, _vid uuid, res_type varchar, _tags jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE
    eval_template($SQL$
      INSERT INTO {{tbl}}_tag
      (resource_id, resource_version_id, scheme, term, label)
      SELECT $1, $2, tg->>'scheme', tg->>'term', tg->>'label'
      FROM jsonb_array_elements($3) tg
    $SQL$, 'tbl', res_type)
  USING _id, _vid, _tags;
  RETURN _id;
END
$$;

--private
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
    EXECUTE
      eval_template($SQL$
        INSERT INTO "{{tbl}}_search_token"
        (resource_id, param, namespace, code, text)
        SELECT $1, $2->>'param', $2->>'system', $2->>'code', $2->>'text'
      $SQL$, 'tbl', res_type)
    USING id, idx;
  END LOOP;

  -- indexing dates
  FOR idx IN
    SELECT unnest(index_date_resource(_rsrs))
  LOOP
    -- RAISE NOTICE 'idx %', idx;
    EXECUTE
    eval_template($SQL$
      INSERT INTO "{{tbl}}_search_date"
      (resource_id, param, "start", "end")
      SELECT $1, $2->>'param', ($2->>'start')::timestamptz, ($2->>'end')::timestamptz
    $SQL$, 'tbl', res_type)
    USING id, idx;
  END LOOP;

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

  -- indexing references
  FOR idx IN
  SELECT unnest(index_reference_resource(_rsrs))
  LOOP
    EXECUTE
    eval_template($SQL$
      INSERT INTO "{{tbl}}_search_reference"
      (resource_id, param, logical_id, resource_type, url)
      SELECT $1, $2->>'param', $2->>'logical_id', $2->>'resource_type', $2->>'url';
    $SQL$, 'tbl', res_type)
    USING id, idx;
  END LOOP;

  -- indexing all references (for includes)
  FOR idx IN
  SELECT unnest(index_all_resource_references(_rsrs))
  LOOP
  EXECUTE
    eval_template($SQL$
      INSERT INTO "{{tbl}}_references"
      (resource_id, path, reference_type, logical_id)
      SELECT $1, $2->>'path', $2->>'reference_type', $2->>'logical_id';
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
      (version_id, logical_id, last_modified_date, published, data)
      SELECT version_id, logical_id, last_modified_date, published, data
      FROM {{tbl}}
      WHERE logical_id = $1;

      INSERT INTO "{{tbl}}_history_tag"
      (id, resource_id, resource_version_id, scheme, term, label)
      SELECT id, resource_id, resource_version_id, scheme, term, label
      FROM {{tbl}}_tag
      WHERE resource_id = $1;

      DELETE FROM "{{tbl}}_sort" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_tag" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_search_string" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_search_token" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_search_date" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_search_reference" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_search_quantity" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}_references" WHERE resource_id = $1;
      DELETE FROM "{{tbl}}" WHERE logical_id = $1;
    $SQL$, 'tbl', lower(res_type))
  USING id;

  RETURN id;
END
$$;

--private
CREATE OR REPLACE FUNCTION
merge_tags(_id uuid, res_type varchar, _tags jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    eval_template($SQL$
      SELECT json_agg(row_to_json(tgs))::jsonb
        FROM (
          SELECT tg->>'scheme' as scheme,
                 tg->>'term' as term,
                 tg->>'label' as label
          FROM jsonb_array_elements($2) tg
          UNION
          SELECT scheme as scheme,
                 term as term,
                 label as label
          FROM {{tbl}}_tag
          WHERE resource_id = $1
        ) tgs
    $SQL$, 'tbl', res_type)
  INTO res USING _id, _tags;

  RETURN res;
END
$$;

-- TODO: implement by UPDATE
CREATE OR REPLACE FUNCTION
update_resource(id uuid, _rsrs jsonb, _tags jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  res uuid;
  new_tags jsonb;
  res_type varchar;
BEGIN
  res_type := lower(_rsrs->>'resourceType');
  new_tags = merge_tags(id, res_type, _tags);
  PERFORM delete_resource(id, res_type);
  res := insert_resource(id, _rsrs, new_tags);
  RETURN res;
END
$$;
--}}}
