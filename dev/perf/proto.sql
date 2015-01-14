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
select count(*) from observation;
--}}}

--{{{
select build_search_query(
  'Observation',
  _parse_param('value-quantity=>37.5&value-quantity=<38.0')
)
--}}}

--{{{
\timing
select jsonb_array_elements#>'{content,valueQuantity}' from
(
select
jsonb_array_elements(
  fhir_search('{}'::jsonb,
  'Observation',
  'value-quantity=>37.5&value-quantity=<38.0')->'entry')
) _
--}}}
