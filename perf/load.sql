DROP TABLE IF EXISTS first_names;
DROP TABLE IF EXISTS last_names;
DROP TABLE IF EXISTS languages;
DROP TABLE IF EXISTS street_names;
DROP TABLE IF EXISTS cities;
DROP TABLE IF EXISTS organization_names;

CREATE TABLE first_names (
  sex text,
  first_name text
);

CREATE TABLE last_names (
  last_name text
);

CREATE TABLE languages (
  code text,
  name text
);

CREATE TABLE street_names (
  street_name text
);

CREATE TABLE cities (
  zip text,
  state text,
  city text,
  latitude float,
  longitude float
);

CREATE TABLE organization_names (
  organization_name text
);

-- COPY first_names (sex, first_name)
--      FROM './perf/data/first_names.csv';
-- COPY last_names (last_name)
--      FROM './perf/data/last_names.csv';
-- COPY languages (code, name)
--      FROM './perf/data/language-codes-iso-639-1-alpha-2.csv'
--      WITH csv;
-- COPY street_names (street_name)
--      FROM './perf/data/street_names.csv';
-- COPY cities (zip, state, city, latitude, longitude)
--      FROM './perf/data/cities.csv'
--      WITH csv;
-- COPY organization_names (organization_name)
--      FROM './perf/data/organization_names.csv';

\echo 'Load fake "first_names".'
\copy first_names (sex, first_name) from './perf/data/first_names.csv'

\echo 'Load fake "last_names".'
\copy last_names (last_name) from './perf/data/last_names.csv'

\echo 'Load fake "languages".'
\copy languages (code, name) from './perf/data/language-codes-iso-639-1-alpha-2.csv' with csv

\echo 'Load fake "street_names".'
\copy street_names (street_name) from './perf/data/street_names.csv'

\echo 'Load fake "cities".'
\copy cities (zip, state, city, latitude, longitude) from './perf/data/cities.csv' with csv

\echo 'Load fake "organization_names".'
\copy organization_names (organization_name) from './perf/data/organization_names.csv'
