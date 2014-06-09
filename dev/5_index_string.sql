--db:fhirb
--{{{

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
--}}}
