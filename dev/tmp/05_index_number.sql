--db:fhirb
--{{{
CREATE OR REPLACE FUNCTION
index_number_resource(rsrs jsonb)
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
    AND search_type = 'number'
  LOOP
    attrs := json_get_in(rsrs, _rest(prm.path));
    FOR item IN SELECT unnest(attrs)
    LOOP
      result := result || json_build_object(
       'param', prm.param_name,
       'value', item)::jsonb;
    END LOOP;
  END LOOP;
  RETURN result;
END
$$;


CREATE OR REPLACE FUNCTION
_search_number_expression(_table varchar, _param varchar, _type varchar, _op varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT
  quote_ident(_table) || '.value ' ||
  CASE
  WHEN _op = '=' THEN
    '= ' || quote_literal(_value)
  WHEN _op = '<' THEN
    '< ' || quote_literal(_value)
  WHEN _op = '>' THEN
    '>' || quote_literal(_value)
  WHEN _op = '~' THEN
    '<@ numrange(' || _value::decimal - _value::decimal * 0.05 || ',' || _value::decimal + _value::decimal * 0.05 || ')'
  ELSE
    '= "unknown operator: ' || _op || '"'
  END
$$;
--}}}
