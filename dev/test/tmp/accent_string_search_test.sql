--db:fhirb -e
SET escape_string_warning=off;

--{{{
\set cfg '{"base":"https://test.me"}'
\set device `cat test/fixtures/device.json`

BEGIN;

  SELECT assert_eq (
    'Joe Acme',
    _unaccent_string('Jóe Ácme'),
    '_unaccent_string');

  WITH device AS (
    SELECT *
    FROM fhir_create(:'cfg', 'Device', :'device'::jsonb, '[]'::jsonb) as bundle
  ), searching AS (
    SELECT d.*,
      fhir_search(:'cfg', 'Device', 'model=Joe') as res,
      fhir_search(:'cfg', 'Device', 'manufacturer=Ácme') as param,
      fhir_search(:'cfg', 'Device', 'model=Jóe') as res_param
    FROM device d
  )
  SELECT
    assert_eq(
      d.bundle#>>'{entry,0,id}',
      d.res#>>'{entry,0,id}',
      'accent in resource'),
    assert_eq(
      d.bundle#>>'{entry,0,id}',
      d.param#>>'{entry,0,id}',
      'accent in search parameter'),
    assert_eq(
      d.bundle#>>'{entry,0,id}',
      d.res_param#>>'{entry,0,id}',
      'accent in resource and search parameter')
  FROM searching d;

ROLLBACK;
--}}}
