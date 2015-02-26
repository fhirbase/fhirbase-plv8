-- #import ../src/tests.sql
-- #import ../src/searh_params.sql

SET search_path TO searh_params;


_get_modifier('subject:Patient.organization:Organization.identifier:text'::text) => 'text'

_get_modifier('subject:Patient.organization:Organization.identifier'::text) => NULL

_get_key('subject:Patient.organization:Organization.identifier:text'::text) => 'subject:Patient.organization:Organization.identifier'

_get_key('subject:Patient.organization:Organization.identifier'::text) => 'subject:Patient.organization:Organization.identifier'

-- number
SELECT row(x.*)::text FROM _parse_param('param=num') x => '({param},=,{num})'

SELECT count(*) FROM _parse_param('param=num&param=num2') => 2::bigint

expect
  SELECT string_agg(row(x.*)::text, ';') FROM _parse_param('param=num&param=num2') x
=> '({param},=,{num});({param},=,{num2})'

SELECT row(x.*)::text FROM _parse_param('param=<num') x  => '({param},<,{num})'
SELECT row(x.*)::text FROM _parse_param('param=<%3Dnum') x => '({param},<=,{num})'
SELECT row(x.*)::text FROM _parse_param('param=>num') x => '({param},>,{num})'
SELECT row(x.*)::text FROM _parse_param('param=>%3Dnum') x => '({param},>=,{num})'
SELECT row(x.*)::text FROM _parse_param('param:missing=true') x => '({param},missing,{true})'
SELECT row(x.*)::text FROM _parse_param('param:missing=false') x => '({param},missing,{false})'

/* -- date */

expect
  SELECT row(x.*)::text FROM _parse_param('param=<date') x
=> '({param},<,{date})'

expect
  SELECT row(x.*)::text FROM _parse_param('param=<%3Ddate') x
=> '({param},<=,{date})'

expect
  SELECT row(x.*)::text FROM _parse_param('param=>date') x
=> '({param},>,{date})'

expect
  SELECT row(x.*)::text FROM _parse_param('param=>%3Ddate') x
=> '({param},>=,{date})'

expect
  SELECT row(x.*)::text FROM _parse_param('param:missing=true') x
=> '({param},missing,{true})'

expect
  SELECT row(x.*)::text FROM _parse_param('param:missing=false') x
=> '({param},missing,{false})'

expect
  SELECT row(x.*)::text FROM _parse_param('param=str') x
=> '({param},=,{str})'

expect
  SELECT row(x.*)::text FROM _parse_param('param:exact=str') x
=> '({param},exact,{str})'

expect
  SELECT row(x.*)::text FROM _parse_param('subject:Patient.name=ups') x
=> '("{subject:Patient,name}",=,{ups})'

/* -- token */

SELECT row(x.*)::text FROM _parse_param('param=~quantity') x => '({param},~,{quantity})'

/* -- reference */

/* /1* ### Chained params ### *1/ */
/* /1* ### Composite Search params ### *1/ */
