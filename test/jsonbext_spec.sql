-- #import ../src/tests.sql
-- #import ../src/fhirbase_json.sql

fhirbase_json._is_array('[1,2]'::jsonb) => true

fhirbase_json._is_array('"a"'::jsonb) => false

fhirbase_json.json_get_in('{"a": 1}'::jsonb, ARRAY['a', 'b']) =>  ARRAY[]::jsonb[]

fhirbase_json._is_array('[{"a":"b"}]'::jsonb) => true

fhirbase_json._is_array('{"a":"b"}'::jsonb) => false

fhirbase_json._is_object('[{"a":"b"}]'::jsonb) => false

fhirbase_json._is_object('{"a":"b"}'::jsonb) => true

expect
  fhirbase_json.json_get_in('{"a":[{"b": [{"c":"c1"},{"c":"c2"}]}, {"b":[{"c":{"obj":"obj"}}]}]}'::jsonb, ARRAY['a','b','c'])
=>  ARRAY['"c1"'::jsonb, '"c2"'::jsonb, '{"obj":"obj"}'::jsonb]

fhirbase_json.json_get_in('{"a": 1}'::jsonb, ARRAY['a']) =>  ARRAY['1'::jsonb]

expect
  fhirbase_json.json_array_to_str_array(ARRAY['1','2']::jsonb[])
=> '{1,2}'::text[]

expect
  fhirbase_json.json_array_to_str_array(ARRAY['"a"'::jsonb,'"b"'::jsonb])
=>  '{a,b}'::text[]

fhirbase_json.jsonb_primitive_to_text('1'::jsonb) => '1'::text

fhirbase_json.jsonb_primitive_to_text('"str"'::jsonb) => 'str'::text

fhirbase_json.jsonb_primitive_to_text('"str"'::jsonb) => 'str'::text

fhirbase_json.jsonb_primitive_to_text('null'::jsonb) => NULL::text

fhirbase_json.assoc('{}'::jsonb, 'a', '1'::jsonb) => '{"a":1}'

fhirbase_json.assoc('{"a":42}'::jsonb, 'a', '1'::jsonb) => '{"a":1}'

fhirbase_json.assoc('{"a":1}'::jsonb, 'a', '42'::jsonb) => '{"a":42}'

expect 'merge'
  fhirbase_json.merge('{"a":1, "b":2, "c":3}'::jsonb, '{"d":4,"e":5}'::jsonb)
=> '{"a": 1, "b": 2, "c": 3, "d": 4, "e": 5}'::jsonb

fhirbase_json.dissoc('{"a":1, "b":2}'::jsonb, 'b') => '{"a":1}'
