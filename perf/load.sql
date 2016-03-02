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

\echo 'Create loading fake date function: "load_dummy_data()".'
DROP FUNCTION IF EXISTS load_dummy_data() CASCADE;
CREATE OR REPLACE FUNCTION load_dummy_data()
RETURNS void AS $$
  BEGIN
    RAISE NOTICE 'Load fake "first_names".';
    COPY first_names (sex, first_name) FROM '/fhirbase/perf/data/first_names.csv';

    RAISE NOTICE 'Load fake "last_names".';
    COPY last_names (last_name) FROM '/fhirbase/perf/data/last_names.csv';

    RAISE NOTICE 'Load fake "languages".';
    COPY languages (code, name) FROM '/fhirbase/perf/data/language-codes-iso-639-1-alpha-2.csv' WITH csv;

    RAISE NOTICE 'Load fake "street_names".';
    COPY street_names (street_name) FROM '/fhirbase/perf/data/street_names.csv';

    RAISE NOTICE 'Load fake "cities".';
    COPY cities (zip, state, city, latitude, longitude) FROM '/fhirbase/perf/data/cities.csv' WITH csv;

    RAISE NOTICE 'Load fake "organization_names".';
    COPY organization_names (organization_name) FROM '/fhirbase/perf/data/organization_names.csv';
  END
$$ LANGUAGE plpgsql;
