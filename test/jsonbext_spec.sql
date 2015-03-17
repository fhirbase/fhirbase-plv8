-- #import ../src/tests.sql
-- #import ../src/jsonbext.sql

jsonbext._is_array('[1,2]'::jsonb) => true

jsonbext._is_array('"a"'::jsonb) => false

jsonbext.json_get_in('{"a": 1}'::jsonb, ARRAY['a', 'b']) =>  ARRAY[]::jsonb[]

jsonbext._is_array('[{"a":"b"}]'::jsonb) => true

jsonbext._is_array('{"a":"b"}'::jsonb) => false

jsonbext._is_object('[{"a":"b"}]'::jsonb) => false

jsonbext._is_object('{"a":"b"}'::jsonb) => true

expect
  jsonbext.json_get_in('{"a":[{"b": [{"c":"c1"},{"c":"c2"}]}, {"b":[{"c":{"obj":"obj"}}]}]}'::jsonb, ARRAY['a','b','c'])
=>  ARRAY['"c1"'::jsonb, '"c2"'::jsonb, '{"obj":"obj"}'::jsonb]

jsonbext.json_get_in('{"a": 1}'::jsonb, ARRAY['a']) =>  ARRAY['1'::jsonb]

expect
  jsonbext.json_array_to_str_array(ARRAY['1','2']::jsonb[])
=> '{1,2}'::text[]

expect
  jsonbext.json_array_to_str_array(ARRAY['"a"'::jsonb,'"b"'::jsonb])
=>  '{a,b}'::text[]

jsonbext.jsonb_primitive_to_text('1'::jsonb) => '1'::text

jsonbext.jsonb_primitive_to_text('"str"'::jsonb) => 'str'::text

jsonbext.jsonb_primitive_to_text('"str"'::jsonb) => 'str'::text

jsonbext.jsonb_primitive_to_text('null'::jsonb) => NULL::text

jsonbext.assoc('{}'::jsonb, 'a', '1'::jsonb) => '{"a":1}'

jsonbext.assoc('{"a":42}'::jsonb, 'a', '1'::jsonb) => '{"a":1}'

jsonbext.assoc('{"a":1}'::jsonb, 'a', '42'::jsonb) => '{"a":42}'

expect 'merge'
  jsonbext.merge('{"a":1, "b":2, "c":3}'::jsonb, '{"d":4,"e":5}'::jsonb)
=> '{"a": 1, "b": 2, "c": 3, "d": 4, "e": 5}'::jsonb

jsonbext.dissoc('{"a":1, "b":2}'::jsonb, 'b') => '{"a":1}'
