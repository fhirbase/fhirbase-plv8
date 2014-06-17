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
    attrs := get_in_path(res, rest(prm.path));
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
