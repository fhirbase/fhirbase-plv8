--db:fhirb
--{{{
CREATE OR REPLACE FUNCTION
index_reference_resource(res jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  prm fhir.resource_indexables%rowtype;
  attrs jsonb[];
  item jsonb;
  result jsonb[] := array[]::jsonb[];
  ref_id varchar;
  ref_type varchar;
BEGIN
  FOR prm IN
    SELECT * FROM fhir.resource_indexables
    WHERE resource_type = res->>'resourceType'
    AND search_type = 'reference'
    AND array_length(path, 1) > 1
  LOOP
    attrs := json_get_in(res, _rest(prm.path));
    -- RAISE NOTICE 'param % | %', prm, attrs;

    FOR item IN SELECT unnest(attrs) LOOP
      IF (item->>'reference') IS NOT NULL THEN
        ref_type := split_part(item->>'reference', '/', 1);
        ref_id := split_part(item->>'reference', '/', 2);
        -- RAISE NOTICE '% : %', ref_type, ref_id;
        result := result || json_build_object('param', prm.param_name, 'logical_id', ref_id, 'resource_type', ref_type, 'url', item->>'reference')::jsonb;
      END IF;
    END LOOP;
  END LOOP;
  RETURN result;
END
$$;

CREATE OR REPLACE FUNCTION
_index_res_ref_recur(path varchar[], res jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  -- t text = jsonb_typeof(res);
  r record;
  ref varchar;
  ref_parts varchar[];
  result jsonb[];
BEGIN
  -- RAISE NOTICE '!!! %', res;
  CASE jsonb_typeof(res)
  WHEN 'object' THEN
    FOR r IN SELECT * FROM jsonb_each(res)
    LOOP
      CASE jsonb_typeof(r.value)
      WHEN 'string' THEN
        ref := jsonb_text_value(r.value);
        IF r.key = 'reference' AND ref ~ '^[a-zA-Z]+/.+$' THEN
          ref_parts := regexp_split_to_array(ref, '/');
          result := result || json_build_object('path', array_to_string(path, '.'), 'reference_type', ref_parts[1], 'logical_id', ref_parts[2])::jsonb;
        END IF;
      WHEN 'object', 'array' THEN
        result := result || _index_res_ref_recur(array_append(path, r.key::varchar), r.value);
      ELSE -- noop
      END CASE;
    END LOOP;
  WHEN 'array' THEN
    FOR r IN SELECT * FROM jsonb_array_elements(res)
    LOOP
      result := result || _index_res_ref_recur(path, r.value);
    END LOOP;
  ELSE -- noop
  END CASE;

  RETURN result;
END
$$;

CREATE OR REPLACE
FUNCTION index_all_resource_references(res jsonb) RETURNS jsonb[]
LANGUAGE sql AS $$
  SELECT _index_res_ref_recur(ARRAY[res->>'resourceType']::varchar[], res);
$$;

CREATE OR REPLACE
FUNCTION _search_reference_expression(_table varchar, _param varchar, _type varchar, _op varchar, _value varchar) RETURNS text
LANGUAGE sql AS $$
  SELECT '('
      ||  quote_ident(_table) || '.logical_id = ' || quote_literal(_value)
      ||  ' OR '
      ||  quote_ident(_table) || '.url = ' || quote_literal(_value)
      ||  ')'
      ||
          CASE WHEN _op <> '=' THEN
            ' AND ' || quote_ident(_table) || '.resource_type = ' || quote_literal(_op)
          ELSE
            ''
          END;
$$;
--}}}
