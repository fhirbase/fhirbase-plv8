-- #import ../src/fhir.sql
create schema if not exists temp;

drop table if exists temp.first_names;
drop table if exists temp.last_names;
drop table if exists temp.languages;
drop table if exists temp.street_names;

create table temp.first_names (
  sex text,
  first_name text
);

create table temp.last_names (
  last_name text
);

create table temp.languages (
  code text,
  name text
);

create table temp.street_names (
  street_name text
);

\copy temp.first_names (sex, first_name) from './perf/data/first_names_shuffled.csv';
\copy temp.last_names (last_name) from './perf/data/last_names_shuffled.csv';
\copy temp.languages (code, name) from './perf/data/language-codes-iso-639-1-alpha-2.csv' with csv;
\copy temp.street_names (street_name) from './perf/data/street_names.csv';

select count(*) from temp.first_names;
select count(*) from temp.last_names;
select count(*) from temp.languages;
select count(*) from temp.street_names;

create table if not exists temp.patient_names (
  sex text,
  first_name text,
  last_name text
);

\set patients_total_count `echo $patients_total_count`

with first_name_source as (
  select sex, first_name
  from temp.first_names
  limit ceil(sqrt((:'patients_total_count')::int))
), last_name_source as (
  select last_name
  from temp.last_names
  limit ceil(sqrt((:'patients_total_count')::int))
)
INSERT into temp.patient_names (sex, first_name, last_name)
SELECT * FROM (
  select sex, first_name, last_name from (
    select first_names.first_name, last_names.last_name,
           CASE WHEN first_names.sex = 'M' THEN 'male' ELSE 'female' END as sex
    from first_name_source as first_names
    cross join last_name_source as last_names) _
  where not exists (select * from temp.patient_names)
) __
ORDER BY RANDOM();

select fhir.generate_tables('{Patient}');
