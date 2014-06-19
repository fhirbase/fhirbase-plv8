--db:fhirb -e
SET escape_string_warning=off;
--{{{
--test get_in_path
SELECT get_in_path('{"a": 1}'::jsonb, ARRAY['a']);
SELECT get_in_path('{"a": 1}'::jsonb, ARRAY['a', 'b']);
SELECT get_in_path('{"a":[{"b": [{"c":"c1"},{"c":"c2"}]}, {"b":[{"c":{"obj":"obj"}}]}]}'::jsonb, ARRAY['a','b','c']);
--}}}

--{{{
  SELECT is_array('[{"a":"b"}]'::jsonb);
--}}}

--{{{
select json_array_to_str_array(ARRAY['"a"'::jsonb,'"b"'::jsonb]);
--}}}
