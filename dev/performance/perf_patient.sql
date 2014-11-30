--db:fhirb
--{{{
\set cfg '{"base":"https://test.me"}'
\set tpl `cat observation.json`
\timing
--}}}
--{{{
DROP TABLE perf_observation;
create table perf_observation (
  logical_id uuid,
  version_id uuid,
  content jsonb
)
--}}}

--{{{
\set cfg '{"base":"https://test.me"}'
\set tpl `cat observation.json`
\timing

INSERT INTO perf_observation
(logical_id, version_id, content)
select
  gen_random_uuid(),
  gen_random_uuid(),
  format(:'tpl'::text, (34 + random()*10))::jsonb
from generate_series(1,900000);
--}}}

--{{{
\timing
alter table perf_observation add column _quantity__value_quantity__value decimal;
alter table perf_observation add column _quantity__value_quantity__code varchar;
alter table perf_observation add column _quantity__value_quantity__namespace varchar;
--}}}

--{{{
\timing

UPDATE perf_observation SET
_quantity__value_quantity__value = (content#>>'{valueQuantity,value}')::decimal,
_quantity__value_quantity__code = content#>>'{valueQuantity,code}',
_quantity__value_quantity__namespace = content#>>'{valueQuantity,system}'

/* Timing is on. */
/* UPDATE 1000000 */
/* Time: 36133.219 ms */
--}}}

--{{{
    CREATE INDEX obs_value_idx ON
    perf_observation (_quantity__value_quantity__value);

    CREATE INDEX obs_logical_idx ON
    perf_observation (logical_id);
--}}}
--{{{
\timing

select * from perf_observation
where _quantity__value_quantity__value > 39
and _quantity__value_quantity__value < 40
ORDER by logical_id DESC
limit 10;

/* Time: 4ms - 8ms */
/* on 1M records */
--}}}
