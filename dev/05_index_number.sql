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
_search_number_expression(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT
  quote_ident(_table) || '.value ' ||

  CASE
  WHEN op = '' OR op IS NULL THEN
    '= ' || quote_literal(p.val)
  WHEN op = '<' THEN
    '< ' || quote_literal(p.val)
  WHEN op = '>' THEN
    '>' || quote_literal(p.val)
  WHEN op = '~' THEN
    '<@ numrange(' || val - val * 0.05 || ',' || val + val * 0.05 || ')'
  ELSE
    '= "unknown operator: ' || op || '"'
  END ||

  CASE WHEN array_length(p.c, 1) = 3 THEN
    CASE WHEN p.c[2] IS NOT NULL AND p.c[2] <> '' THEN
      ' AND ' || quote_ident(_table) || '.system = ' || quote_literal(p.c[2])
    ELSE
      ''
    END ||
    CASE WHEN p.c[3] IS NOT NULL AND p.c[3] <> '' THEN
      ' AND ' || quote_ident(_table) || '.units = ' || quote_literal(p.c[3])
    ELSE
      ''
    END
  WHEN array_length(p.c, 1) = 1 THEN
    ''
  ELSE
    '"wrong number of compoments of search string, must be 1 or 3"'
  END
  FROM
  (SELECT
    regexp_split_to_array(_value, '\|') AS c,
    (regexp_matches(split_part(_value, '|', 1), '^(<|>|~)?'))[1] AS op,
    (regexp_matches(split_part(_value, '|', 1), '^(<|>|~)?(.+)$'))[2]::numeric AS val) p;
$$;
--}}}
