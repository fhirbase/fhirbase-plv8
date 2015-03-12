-- #import ../src/fhir.sql
create schema if not exists temp;

drop table if exists temp.first_names;
drop table if exists temp.last_names;

create table temp.first_names (
  sex text,
  first_name text
);

create table temp.last_names (
  last_name text
);


\copy temp.first_names (sex, first_name) from './perf/data/first_names_shuffled.csv';
\copy temp.last_names (last_name) from './perf/data/last_names_shuffled.csv';

select count(*) from temp.first_names;
select count(*) from temp.last_names;

create table if not exists temp.patient_names (
  sex text,
  first_name text,
  last_name text
);

\set patients_total_count `echo $patients_total_count`

with x as (
  select sex, first_name
  from temp.first_names
  limit ceil(sqrt((:'patients_total_count')::int))
), y as (
  select last_name
  from temp.last_names
  limit ceil(sqrt((:'patients_total_count')::int))
)
INSERT into temp.patient_names (sex, first_name, last_name)
select sex, first_name, last_name from (
  select xx.first_name, yy.last_name,
         CASE WHEN xx.sex = 'M' THEN 'male' ELSE 'female' END as sex
  from x as xx cross join y as yy) _
where not exists (select * from temp.patient_names);

select fhir.generate_tables('{Patient}');
