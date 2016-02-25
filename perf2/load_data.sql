-- #import ../src/fhir.sql
create schema if not exists temp;

drop table if exists temp.first_names;
drop table if exists temp.last_names;
drop table if exists temp.languages;
drop table if exists temp.street_names;
drop table if exists temp.cities;
drop table if exists temp.organization_names;

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

create table temp.cities (
  zip text,
  state text,
  city text,
  latitude float,
  longitude float
);

create table temp.organization_names (
  organization_name text
);

\copy temp.first_names (sex, first_name) from './perf/data/first_names.csv';
\copy temp.last_names (last_name) from './perf/data/last_names.csv';
\copy temp.languages (code, name) from './perf/data/language-codes-iso-639-1-alpha-2.csv' with csv;
\copy temp.street_names (street_name) from './perf/data/street_names.csv';
\copy temp.cities (zip, state, city, latitude, longitude) from './perf/data/cities.csv' with csv;
\copy temp.organization_names (organization_name) from './perf/data/organization_names.csv';

SELECT 1;
