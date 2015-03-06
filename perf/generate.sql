--db:test
--{{{
create schema if not exists temp;

drop table if exists temp.human_names;

create table temp.human_names (
  year text,
  name text,
  percent numeric,
  sex text
);

\set names `pwd`/given_names.csv
\copy temp.human_names (year,name,percent,sex) from  './given_names.csv' with CSV;
--}}}

--{{{
select fhir.generate_tables('{Patient}');
--}}}

--{{{
\timing
with x as (
  select *, row_number() over () from (
    select * from temp.human_names
     order by year
  ) _
), y as (
  select *, row_number() over () from (
    select * from temp.human_names
     order by percent
  ) _
), names as (
  select x.name as given_name,
         y.name || substring(reverse(lower(x.name)) from 1 for 3) as family_name,
         CASE WHEN x.sex = 'boy' THEN 'male' ELSE 'female' END as gender,
         (x.year::int + y.year::int)/2
         || '-'
         || lpad(
              (mod(ascii(x.name) +  ascii(y.name), 12) + 1)::text, 2, '0'
            )
         || '-'
         || lpad(
              (mod(ascii(x.name) +  ascii(y.name), 28) + 1)::text, 2, '0'
            )
        as birthDate
  from x
  join y on x.row_number = y.row_number
  limit 1000000
)
INSERT into patient (logical_id, version_id, content)
SELECT obj->'id', obj->>'{meta,versionId}', obj FROM (
SELECT
  json_build_object(
   'id', gen_random_uuid(),
   'meta', json_build_object(
      'versionId', gen_random_uuid(),
      'lastUpdated', CURRENT_TIMESTAMP
    ),
   'resourceType', 'Patient',
   'gender', gender,
   'birthDate', birthDate,
   'name', ARRAY[
     json_build_object(
      'given', ARRAY[given_name],
      'family', ARRAY[family_name]
     )
   ]
  )::jsonb as obj
  FROM names
  LIMIT 1000000
) _
--}}}

--{{{
select count(*) from patient;
select admin.admin_disk_usage_top(10);
--}}}
