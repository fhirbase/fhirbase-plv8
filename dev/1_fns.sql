--db:fhirb
--{{{
CREATE OR REPLACE FUNCTION
eval_template(_tpl text, variadic _bindings varchar[])
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
result text := _tpl;
BEGIN
  FOR i IN 1..(array_upper(_bindings, 1)/2) LOOP
    result := replace(result, '{{' || _bindings[i*2 - 1] || '}}', _bindings[i*2]);
  END LOOP;
  RETURN result;
END
$$;

CREATE OR REPLACE FUNCTION eval_ddl(str text)
RETURNS text AS
$BODY$
  begin
    EXECUTE str;
    RETURN str;
  end;
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE
FUNCTION array_pop(ar varchar[])
  RETURNS varchar[] language sql AS $$
    SELECT ar[array_lower(ar,1) : array_upper(ar,1) - 1];
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION butlast(ar varchar[])
  RETURNS varchar[] language sql AS $$
    SELECT ar[array_lower(ar,1) : array_upper(ar,1) - 1];
$$ IMMUTABLE;

-- remove last item from array
CREATE OR REPLACE
FUNCTION array_tail(ar varchar[])
  RETURNS varchar[] language sql AS $$
    SELECT ar[2 : array_upper(ar,1)];
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION rest(ar varchar[])
  RETURNS varchar[] language sql AS $$
    SELECT ar[2 : array_upper(ar,1)];
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION array_last(ar varchar[])
  RETURNS varchar language sql AS $$
    SELECT ar[array_length(ar,1)];
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION column_name(name varchar, type varchar)
  RETURNS varchar language sql AS $$
    SELECT replace(name, '[x]', '' || type);
$$  IMMUTABLE;

--{{{
CREATE OR REPLACE FUNCTION
is_array(json jsonb)
  RETURNS boolean language sql AS $$
    SELECT
    CASE WHEN substring(json::text  from 1 for 1) = '['
      THEN true ELSE false
    END;
$$  IMMUTABLE;

CREATE OR REPLACE FUNCTION
is_obj(json jsonb)
  RETURNS boolean language sql AS $$
    SELECT
    CASE WHEN substring(json::text  from 1 for 1) = '{'
      THEN true ELSE false
    END;
$$  IMMUTABLE;

CREATE OR REPLACE FUNCTION
get_in_path(json jsonb, path varchar[])
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
item jsonb;
acc jsonb[] := array[]::jsonb[];
BEGIN
  --RAISE NOTICE 'in with % and path %', json, path;
  IF json is NULL THEN
    --RAISE NOTICE 'ups';
    RETURN array[]::jsonb[];
  END IF;

  IF array_length(path, 1) IS NULL THEN
    --RAISE NOTICE 'return %', json;
    RETURN array[json];
  END IF;

  IF is_array(json) THEN
    FOR item IN
      SELECT jsonb_array_elements(json)
    LOOP
      acc := acc || get_in_path(item,path);
    END LOOP;
    RETURN acc;
  ELSIF is_obj(json) THEN
    RETURN get_in_path(json->path[1], rest(path));
  ELSE
    RETURN array[]::jsonb[];
  END IF;
END
$$;

--SELECT get_in_path('{"a": 1}'::jsonb, ARRAY['a']);

--SELECT get_in_path('{"a":[{"b": [{"c":"c1"},{"c":"c2"}]}, {"b":[{"c":"c3"}]}]}'::jsonb, ARRAY['a','b','c']);

--SELECT is_array('[{"a":"b"}]'::jsonb);
--}}}
