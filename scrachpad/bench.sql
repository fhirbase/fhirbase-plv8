--db:test
--{{{
--create extension unaccent;
\timing
select
fhirbase_json.json_get_in(content, '{name,family}')
from patient
where fhirbase_json.json_get_in(content, '{name,family}') = '{\"uno\"}'::jsonb[]
limit 10
;
--Time: 3543.029 ms
--}}}

--{{{
--create extension unaccent;
\timing
explain analyze select *
from patient
where content = '{"name":"ups"}'::jsonb
limit 10
;
--seq scan
--Time: 57.849 ms
--}}}


--{{{
--create extension unaccent;
\timing
explain analyze select *
from patient
where content#>>'{name,0,family}' = 'ups'
limit 10

-- seq scan with function
-- Time: 104.724 ms
;
--seq scan
--Time: 57.849 ms
--}}}


--{{{
--create extension plv8;

DROP FUNCTION plv8_test(json, text[]);
CREATE OR REPLACE FUNCTION plv8_test(content json, path text[])
RETURNS json AS $$
  var result = []
  function walk(obj, path){
    //plv8.elog(WARNING, JSON.stringify(path));
    //plv8.elog(WARNING, JSON.stringify(obj));
    if(path.length < 1){
      result.push(obj);
      return;
    }

    if(Array.isArray(obj)){
      obj.forEach(function(x){ walk(x, path) })
    } else if (obj !== null && typeof obj === 'object') {
      var newobj = obj[path[0]]
      if (newobj) {
        var newpath = path.slice(1);
        //plv8.elog(WARNING, JSON.stringify(newpath));
        walk(newobj, newpath)
      }
    }
  }
  walk(content, path)
  return result
$$ LANGUAGE plv8 IMMUTABLE STRICT;

select plv8_test('{"a": [{"b": 1}, {"b":2}]}'::json, '{a,b}');

\timing
select plv8_test(content::json, '{name,family}')
from patient
where plv8_test(content::json, '{name,family}')::text = '["ups"]'
limit 10
--Time: 2600.163 ms
--}}}


--{{{
create extension jsonb_extra;

\timing
select jsonb_extract(content, '{name,family}')
from patient
where jsonb_extract(content, '{name,family}')::text = '["ups"]'
limit 10
--Time: 145.213 ms
--}}}


