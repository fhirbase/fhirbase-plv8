-- #import ../src/fhir.sql
create schema if not exists temp;

drop table if exists temp.human_names;

create table temp.human_names (
  year text,
  name text,
  percent numeric,
  sex text
);

\copy temp.human_names (year,name,percent,sex) from  './perf/given_names.csv' with CSV;

select fhir.generate_tables('{Patient}');
