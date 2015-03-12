-- #import ../src/fhir.sql
create schema if not exists temp;

drop table if exists temp.human_names;

create table temp.human_names (
  year text,
  name text,
  percent numeric,
  sex text
);

\copy temp.human_names (year,name,percent,sex) from './perf/given_names.csv' with CSV;

create table if not exists temp.human_names_and_lastnames (
  name text,
  family text,
  percent numeric,
  sex text
);

\set patients_total_count `echo $patients_total_count`
with x as (
  select name, sex, avg(percent) as per
  from temp.human_names
  group by name, sex
  order by per desc
  limit ceil(sqrt((:'patients_total_count')::int))
), y as (
  select name, avg(percent) as per
  from temp.human_names
  group by name
  order by per desc
  limit ceil(sqrt((:'patients_total_count')::int))
)
INSERT into temp.human_names_and_lastnames (name, family, sex, percent)
select name, family, sex, perc from (
  select xx.name as name,
         yy.name || xx.name as family,
         CASE WHEN xx.sex = 'boy' THEN 'male' ELSE 'female' END as sex,
         xx.per * yy.per as perc
  from x as xx cross join y as yy
  order by perc desc) _
where not exists (select * from temp.human_names_and_lastnames);

select fhir.generate_tables('{Patient}');
