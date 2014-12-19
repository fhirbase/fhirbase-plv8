--db:fhirb -e
--{{{
SET escape_string_warning=off;

SELECT assert_eq(
  _tpl('{{a}}={{b}}','a','A','b','B'),
  'A=B',
  '_tpl');

SELECT assert_eq(
  _butlast('{1,2,3}'::varchar[]),
  '{1,2}'::varchar[],
  '_butlast');


SELECT assert(
   _is_descedant('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[])
  , '_is_descedant');

SELECT assert(
   NOT _is_descedant('{1,2,3,5}'::varchar[], '{1,2,3,4,5}'::varchar[])
  , '_is_descedant');

SELECT assert_eq(
   _subpath('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[])
  , '{4,5}'::varchar[]
  , '_subpath');

SELECT assert_eq(
   _rest('{1,2,3,4,5}'::varchar[])
  , '{2,3,4,5}'::varchar[]
  , '_rest');

SELECT assert_eq(
   _last('{1,2,3,4,5}'::varchar[])
  , '5'
  , '_last');

SELECT assert(
   _is_array('[1,2]'::jsonb)
  , '_is_array');

SELECT assert(
   NOT _is_array('"a"'::jsonb)
  , '_is_array');

SELECT assert_eq(
  json_get_in('{"a": 1}'::jsonb, ARRAY['a', 'b']),
  ARRAY[]::jsonb[],
  'get a');

SELECT assert(
  _is_array('[{"a":"b"}]'::jsonb), 'is_array');

SELECT assert(
  NOT _is_array('{"a":"b"}'::jsonb), 'not is_array');

SELECT assert(
  NOT _is_object('[{"a":"b"}]'::jsonb), 'is_object');

SELECT assert(
  _is_object('{"a":"b"}'::jsonb), 'is_object');

SELECT assert_eq(
  json_get_in('{"a":[{"b": [{"c":"c1"},{"c":"c2"}]}, {"b":[{"c":{"obj":"obj"}}]}]}'::jsonb, ARRAY['a','b','c']),
  ARRAY['"c1"'::jsonb, '"c2"'::jsonb, '{"obj":"obj"}'::jsonb],
  'get abc');

SELECT assert_eq(
  json_get_in('{"a": 1}'::jsonb, ARRAY['a']),
  ARRAY['1'::jsonb],
  'get a');



select assert_eq(
  json_array_to_str_array(ARRAY['"a"'::jsonb,'"b"'::jsonb]),
  '{a,b}'::varchar[],
  'json_array_to_str_array');

SELECT assert_eq('a,b$c|d',
   _fhir_unescape_param('a\,b\$c\|d'),
   '_fhir_unescape_param');

SELECT assert_eq(ARRAY['a,b','c,d'],
   (SELECT array_agg(value)
     FROM _fhir_spilt_to_table('a\,b,c\,d')),
    '_fhir_spilt_to_table'
   );

\set old_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'
\set new_tags '[{"scheme": "http://pt2.com", "term": "http://pt/vip2", "label":"pt2"}]'


SELECT assert_eq(2,
  jsonb_array_length(_merge_tags(:'old_tags'::jsonb, :'new_tags'::jsonb)),
  '_merge_tags'
);

SELECT assert_eq(1,
  jsonb_array_length(_merge_tags(:'old_tags'::jsonb, :'old_tags'::jsonb)),
  '_merge_tags'
);
--}}}
