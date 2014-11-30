--db:fhirb
--{{{
\set cfg '{"base":"https://test.me"}'
\set tpl `cat observation.json`
\timing

select count(
fhir_create(:'cfg', 'Observation',
  format(:'tpl'::text, (34 + random()*10))::jsonb,
  '[]'::jsonb))
from generate_series(1,100000);
--}}}

--{{{
select count(*) from observation_search_token;
--}}}

--{{{
\dt obser*
--}}}
