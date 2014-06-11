--db:fhirb
--{{{
CREATE OR REPLACE FUNCTION
index_quantity_resource(rsrs jsonb)
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
    AND search_type = 'quantity'
  LOOP
    attrs := get_in_path(rsrs, rest(prm.path));

    FOR item IN SELECT unnest(attrs)
    LOOP
      RAISE NOTICE '%', item;
    END LOOP;
  END LOOP;
  RETURN null::jsonb[];
END
$$;
--}}}
