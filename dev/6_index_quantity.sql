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
    attrs := json_get_in(rsrs, _rest(prm.path));
    FOR item IN SELECT unnest(attrs)
    LOOP
      result := result || json_build_object(
       'param', prm.param_name,
       'value', item->'value',
       'comparator', item->'comparator',
       'units', item->'units',
       'system', item->'system',
       'code', item->'code')::jsonb;
    END LOOP;
  END LOOP;
  RETURN result;
END
$$;
--}}}
