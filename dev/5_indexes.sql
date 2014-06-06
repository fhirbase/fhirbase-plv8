--db:fhirb
--{{{
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION
index_string_complex_type(_path varchar[], _item jsonb)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE
  el fhir.expanded_resource_elements%rowtype;
  vals varchar[] := array[]::varchar[];
BEGIN
  FOR el IN
    SELECT * FROM fhir.expanded_resource_elements
    WHERE is_subpath(_path, path) = true
    AND is_primitive = true
  LOOP
    --RAISE NOTICE '---';
    --RAISE NOTICE 'extracting el %', el;
    vals := vals || json_array_to_str_array(get_in_path(_item, relative_path(_path, el.path)));
  END LOOP;
  RETURN array_to_string(vals, ' , ');
END;
$$;

CREATE OR REPLACE FUNCTION
index_token_complex_type(_path varchar[], _item jsonb)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE
  el fhir.expanded_resource_elements%rowtype;
  vals varchar[] := array[]::varchar[];
BEGIN
 --support
 /* Identifier */
 /* CodeableConcept */
 /* Coding */
END;
$$;

DROP FUNCTION IF EXISTS index_string_resource(jsonb);

CREATE OR REPLACE FUNCTION
index_string_resource(rsrs jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
prm fhir.resource_indexables%rowtype;
attrs jsonb[];
item jsonb;
index_vals varchar[];
result jsonb[] := array[]::jsonb[];
BEGIN
  FOR prm IN
    SELECT * FROM fhir.resource_indexables
    WHERE resource_type = rsrs->>'resourceType'
    AND search_type = 'string'
    AND array_length(path, 1) > 1
  LOOP
    --RAISE NOTICE '---';
    --RAISE NOTICE 'param %', prm;
    index_vals := ARRAY[]::varchar[];

    attrs := get_in_path(rsrs, rest(prm.path));

    IF prm.is_primitive THEN
      index_vals := json_array_to_str_array(attrs);
    ElSE
      FOR item IN SELECT unnest(attrs)
      LOOP
        index_vals := index_vals || index_string_complex_type(prm.path, item);
      END LOOP;
    END IF;
    --RAISE NOTICE 'index <%>: %', prm.param_name, index_vals;
    IF array_length(index_vals, 1) > 0 THEN
      result := array_append(result, json_build_object('param', prm.param_name, 'value', index_vals)::jsonb);
    END IF;
  END LOOP;
  RETURN result;
END
$$;


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
      ($1,$2,$3, $4, $5)
    $SQL$, 'tbl', res_type)
  USING id, id, published, published, _rsrs;

  -- indexing
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

  /* --select inserted record */
  /* EXECUTE */
  /*   eval_template($SQL$ */
  /*     SELECT * FROM {{tbl}} WHERE logical_id = $1 LIMIT 1 */
  /*   $SQL$, 'tbl', res_type) */
  /* INTO rec USING id; */

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
