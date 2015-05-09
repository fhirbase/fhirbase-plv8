--db:fhirbase
--{{{
select
(content#>>'{compose,import}') as import,
content#>>'{compose,include,0}' as include,
content#>>'{compose,exclude,0}' as exclude,
logical_id, content
from valueset
where (content#>>'{compose,import}') is not null
--}}}

--{{{
select logical_id, content from valueset
where (content->>'define') is not null
and (content->>'compose') is not null
--}}}

--{{{
select
logical_id,
content#>>'{compose,include,0,system}',
content#>>'{compose,include,0,filter}',
content#>>'{compose,include,0}'
from valueset
where (content#>>'{compose,include,0,filter}')  is not null
limit 10
--}}}
--{{{

include + exclude
group by system

=> sql expression

defines: => naming_system & valueset with include all

[{ system:
   include: {filter: [], concept: []}
   exclude: {filter: [], concept: []}]

--}}}

--{{{
select
logical_id,
content#>>'{compose,exclude,0,system}',
content#>>'{compose,exclude,0,filter}' as exclude,
content#>>'{compose,include,0,filter}' as include,
content#>>'{compose,exclude,0}'
from valueset
where
(content#>>'{compose,exclude,0,filter}')  is not null
limit 10
--}}}


--{{{
drop table defined_codes;

create table defined_codes (
  valueset_id text,
  system text,
  code text,
  display text,
  definition text
);
--}}}

--{{{

INSERT into defined_codes (valueset_id, system, code, display, definition)
select
logical_id
,system
, x->>'code' as code
, x->>'display' as display
, x->>'definition' as definition
--, x
from (
  select
  logical_id,
  content#>>'{define,system}' as system,
  jsonb_array_elements(content#>'{define,concept}') as x
  from valueset
  where (content->>'define') is not null
  and (content->>'compose') is null
) _

--}}}

--{{{

\timing
select * from defined_codes
where valueset_id ilike  '%sta%'
and display ilike '%act%'
limit 100;
--}}}

--{{{
select distinct valueset_id from defined_codes
limit 10;
--}}}

--{{{
select logical_id
from valueset
limit 10;
--}}}

--{{{

\dt naming*

select fhir.generate_tables('{NamingSystem}');

--}}}
--{{{
\d valueset
select fhirbase_terminology.expand('v3-Race','india');
--}}}

--{{{
select logical_id, content from valueset
where (content->>'define') is not null
and (content->>'compose') is not null
--}}}

--{{{
select count(*) from valueset
where (content->>'define') is not null
and (content->>'compose') is  null
--}}}

--{{{
drop table defined_codes;

create table defined_codes (
  valueset_id text,
  system text,
  code text,
  display text,
  definition text
);
--}}}

--{{{

INSERT into defined_codes (valueset_id, system, code, display, definition)
select
logical_id
,system
, x->>'code' as code
, x->>'display' as display
, x->>'definition' as definition
--, x
from (
  select
  logical_id,
  content#>>'{define,system}' as system,
  jsonb_array_elements(content#>'{define,concept}') as x
  from valueset
  where (content->>'define') is not null
) _

--}}}

--{{{

\timing
select * from defined_codes
where valueset_id ilike  '%sta%'
and display ilike '%act%'
limit 100;
--}}}

--{{{
select count(*) from defined_codes;
--}}}

--{{{
select logical_id from valueset
limit 10;
--}}}

--{{{

select fhirbase_terminology.expand('diagnostic-report-status', '');

--}}}
