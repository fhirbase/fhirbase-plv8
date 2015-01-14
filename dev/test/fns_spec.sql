_tpl('{{a}}={{b}}','a','A','b','B') =>  'A=B'

_butlast('{1,2,3}'::varchar[]) => '{1,2}'::varchar[]

_is_descedant('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[]) =>  true

_is_descedant('{1,2,3,5}'::varchar[], '{1,2,3,4,5}'::varchar[]) => false

_subpath('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[]) =>  '{4,5}'::varchar[]

_rest('{1,2,3,4,5}'::varchar[]) => '{2,3,4,5}'::varchar[]

_last('{1,2,3,4,5}'::varchar[]) => '5'

_is_array('[1,2]'::jsonb) => true

_is_array('"a"'::jsonb) => false

json_get_in('{"a": 1}'::jsonb, ARRAY['a', 'b']) =>  ARRAY[]::jsonb[]

_is_array('[{"a":"b"}]'::jsonb) => true

_is_array('{"a":"b"}'::jsonb) => false

_is_object('[{"a":"b"}]'::jsonb) => false

_is_object('{"a":"b"}'::jsonb) => true

expect
  json_get_in('{"a":[{"b": [{"c":"c1"},{"c":"c2"}]}, {"b":[{"c":{"obj":"obj"}}]}]}'::jsonb, ARRAY['a','b','c'])
=>  ARRAY['"c1"'::jsonb, '"c2"'::jsonb, '{"obj":"obj"}'::jsonb]

json_get_in('{"a": 1}'::jsonb, ARRAY['a']) =>  ARRAY['1'::jsonb]

expect
  json_array_to_str_array(ARRAY['"a"'::jsonb,'"b"'::jsonb])
=>  '{a,b}'::varchar[]

_fhir_unescape_param('a\,b\$c\|d') => 'a,b$c|d'

expect
 SELECT array_agg(value)
   FROM _fhir_spilt_to_table('a\,b,c\,d')
=> ARRAY['a,b','c,d']

\set old_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'
\set new_tags '[{"scheme": "http://pt2.com", "term": "http://pt/vip2", "label":"pt2"}]'

expect
  jsonb_array_length(_merge_tags(:'old_tags'::jsonb, :'new_tags'::jsonb))
=> 2

expect
  jsonb_array_length(_merge_tags(:'old_tags'::jsonb, :'old_tags'::jsonb))
=> 1
