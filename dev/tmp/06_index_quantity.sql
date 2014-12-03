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

CREATE OR REPLACE FUNCTION
_search_quantity_expression(_table varchar, _param varchar, _type varchar, _op varchar, _value varchar)
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
  END ||

  CASE WHEN array_length(c, 1) = 3 THEN
    CASE WHEN c[2] IS NOT NULL AND c[2] <> '' THEN
      ' AND ' || quote_ident(_table) || '.system = ' || quote_literal(c[2])
    ELSE
      ''
    END ||
    CASE WHEN c[3] IS NOT NULL AND c[3] <> '' THEN
      ' AND ' || quote_ident(_table) || '.units = ' || quote_literal(c[3])
    ELSE
      ''
    END
  WHEN array_length(c, 1) = 1 THEN
    ''
  ELSE
    '"wrong number of compoments of search string, must be 1 or 3"'
  END
  FROM
  (SELECT regexp_split_to_array(_value, '\|') AS c, split_part(_value, '|', 1)::numeric AS p) _
$$;
--}}}
