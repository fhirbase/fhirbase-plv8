--db:fhirb
--{{{

/* Hardcode complex type to token logic */
/* * CodeableConcept */
/* * Coding */
/* * Identifier */

CREATE OR REPLACE FUNCTION
index_primitive_to_token( _param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  val varchar;
  res jsonb[] := array[]::jsonb[];
BEGIN
  val := json_build_object('x', _item)->>'x';

  RETURN array[json_build_object(
    'param', _param_name,
    'text', val,
    'code', val
  )::jsonb];
END;
$$;

CREATE OR REPLACE FUNCTION
index_coding_to_token(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  res jsonb[] := array[]::jsonb[];
BEGIN
  RETURN array[json_build_object(
    'param', _param_name,
    'text', _item->>'display',
    'code', _item->>'code',
    'system', _item->>'system'
  )::jsonb];
END;
$$;

CREATE OR REPLACE FUNCTION
index_codeable_concept_to_token(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  coding jsonb;
  res jsonb[] := array[]::jsonb[];
BEGIN
  IF (_item->'text') IS NOT NULL THEN
    res := res || json_build_object('param', _param_name, 'text', _item->>'text')::jsonb;
  END IF;

  FOR coding IN
    SELECT jsonb_array_elements(_item->'coding')
  LOOP
    res := res || index_coding_to_token(_param_name, coding);
  END LOOP;

  RETURN res;
END;
$$;

CREATE OR REPLACE FUNCTION
index_identifier_to_token(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  res jsonb[] := array[]::jsonb[];
BEGIN
  RETURN array[json_build_object(
    'param', _param_name,
    'text', _item->>'label',
    'code', _item->>'value',
    'system', _item->>'system'
  )::jsonb];
END;
$$;


CREATE OR REPLACE FUNCTION
index_token_resource(rsrs jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  prm fhir.resource_indexables%rowtype;
  attrs jsonb[];
  item jsonb;
  result jsonb[] := array[]::jsonb[];
BEGIN
  FOR prm IN
    SELECT * FROM fhir.resource_indexables
    WHERE resource_type = rsrs->>'resourceType'
    AND search_type = 'token'
    AND param_name <> '_id'
  LOOP
    attrs := get_in_path(rsrs, rest(prm.path));

    --RAISE NOTICE 'item %', attrs;

    FOR item IN SELECT unnest(attrs)
    LOOP
      CASE
      WHEN prm.type = 'Coding' THEN
        result := result || index_coding_to_token(prm.param_name, item);
      WHEN prm.type = 'CodeableConcept' THEN
        result := result || index_codeable_concept_to_token(prm.param_name, item);
      WHEN prm.type = 'Identifier' THEN
        result := result || index_identifier_to_token(prm.param_name, item);
      WHEN prm.is_primitive = true THEN
        result := result || index_primitive_to_token(prm.param_name, item);
      ELSE
        RAISE NOTICE 'unexpected index % : %', prm, attrs;
      END CASE;
    END LOOP;
  END LOOP;
  RETURN result;
END
$$;
--}}}
