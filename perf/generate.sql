\echo 'Create generation function: "random(a numeric, b numeric)".'
DROP FUNCTION IF EXISTS random(a numeric, b numeric) CASCADE;
CREATE OR REPLACE FUNCTION random(a numeric, b numeric)
RETURNS numeric AS $$
  SELECT ceil(a + (b - a) * random())::numeric;
$$ LANGUAGE SQL;

\echo 'Create generation function: "random_elem(a anyarray)".'
DROP FUNCTION IF EXISTS random_elem(a anyarray) CASCADE;
CREATE OR REPLACE FUNCTION random_elem(a anyarray)
RETURNS anyelement AS $$
  SELECT a[1 + floor(RANDOM() * array_length(a, 1))];
$$ LANGUAGE SQL;

\echo 'Create generation function: "random_date()".'
DROP FUNCTION IF EXISTS random_date() CASCADE;
CREATE OR REPLACE FUNCTION random_date()
RETURNS text AS $$
  SELECT random(1900, 2010)::text
           || '-'
           || lpad(random(1, 12)::text, 2, '0')
           || '-'
           || lpad(random(1, 28)::text, 2, '0');
$$ LANGUAGE SQL;

\echo 'Create generation function: "random_phone()".'
DROP FUNCTION IF EXISTS random_phone() CASCADE;
CREATE OR REPLACE FUNCTION random_phone()
RETURNS text AS $$
  SELECT '+' || random(1, 12)::text ||
         ' (' || random(1, 999)::text || ') ' ||
         lpad(random(1, 999)::text, 3, '0') ||
         '-' ||
         lpad(random(1, 99)::text, 2, '0') ||
         '-' ||
         lpad(random(1, 99)::text, 2, '0')
$$ LANGUAGE SQL;

\echo 'Create generation function: "make_address(_street_name_ text, _zip_ text, _city_ text, _state_ text)".'
DROP FUNCTION IF EXISTS make_address(_street_name_ text, _zip_ text, _city_ text, _state_ text) CASCADE;
CREATE OR REPLACE FUNCTION make_address(_street_name_ text, _zip_ text, _city_ text, _state_ text)
RETURNS jsonb AS $$
  select array_to_json(ARRAY[
    json_build_object(
      'use', 'home',
      'line', ARRAY[_street_name_ || ' ' || random(0, 100)::text],
      'city', _city_,
      'postalCode', _zip_::text,
      'state', _state_,
      'country', 'US'
    )
  ])::jsonb;
$$ LANGUAGE SQL;

\echo 'Create generation function: "insert_organizations()".'
DROP FUNCTION IF EXISTS insert_organizations() CASCADE;
CREATE OR REPLACE FUNCTION insert_organizations()
RETURNS bigint AS $$
  with organizations_source as (
    select organization_name, row_number() over ()
    from organization_names
    order by random()
  ), street_names_source as (
    select street_name, row_number() over ()
    from street_names
    order by random()
  ), cities_source as (
    select city, zip, state, row_number() over ()
    from cities
    order by random()
  ), organization_data as (
    select *,
           random_phone() as phone
    from organizations_source
    join street_names_source using (row_number)
    join cities_source using (row_number)
  ), inserted as (
    INSERT into organization (id, version_id, resource)
    SELECT obj->>'id', obj#>>'{meta,versionId}', obj
    FROM (
      SELECT
        json_build_object(
         'resourceType', 'Organization',
         'id', gen_random_uuid(),
         'name', organization_name,
         'telecom', ARRAY[
           json_build_object(
            'system', 'phone',
            'value', phone,
            'use', 'work'
           )
         ],
         'address', make_address(street_name, zip, city, state)
        )::jsonb as obj
        FROM organization_data
    ) _
    RETURNING id
  )
  select count(*) inserted;
$$ LANGUAGE SQL;

\echo 'Create generation function: "insert_practitioners(_total_count_ integer)".'
DROP FUNCTION IF EXISTS insert_practitioners(_total_count_ integer) CASCADE;
CREATE OR REPLACE FUNCTION insert_practitioners(_total_count_ integer)
RETURNS bigint AS $$
  with first_names_source as (
    select *, row_number() over () from (
      select CASE WHEN sex = 'M' THEN 'male' ELSE 'female' END as sex,
             first_name
      from first_names
      order by random()
      limit _total_count_) _
  ), last_names_source as (
    select *, row_number() over () from (
      select last_name
      from last_names
      order by random()
      limit _total_count_) _
  ), practitioner_data as (
    select *
    from first_names_source
    join last_names_source using (row_number)
  ), inserted as (
    INSERT into practitioner (id, version_id, resource)
    SELECT obj->>'id', obj#>>'{meta,versionId}', obj
    FROM (
      SELECT
        json_build_object(
         'resourceType', 'Practitioner',
         'id', gen_random_uuid(),
         'name', ARRAY[
           json_build_object(
            'given', ARRAY[first_name],
            'family', ARRAY[last_name]
           )
         ]
        )::jsonb as obj
        FROM practitioner_data
    ) _
    RETURNING id
  )
  select count(*) from practitioner_data;
$$ LANGUAGE SQL;

\echo 'Create generation function: "insert_patients(_total_count_ integer)".'
DROP FUNCTION IF EXISTS insert_patients(_total_count_ integer) CASCADE;
CREATE OR REPLACE FUNCTION insert_patients(_total_count_ integer)
RETURNS bigint AS $$
  with first_names_source as (
    select CASE WHEN sex = 'M' THEN 'male' ELSE 'female' END as sex,
           first_name,
           row_number() over ()
    from first_names
    cross join generate_series(0, ceil(_total_count_::float
                                       / (select count(*)
                                          from first_names)::float)::integer)
    order by random()
  ), last_names_source as (
    select last_name, row_number() over ()
    from last_names
    cross join generate_series(0, ceil(_total_count_::float
                                       / (select count(*)
                                          from last_names)::float)::integer)
    order by random()
  ), street_names_source as (
    select street_name, row_number() over ()
    from street_names
    cross join generate_series(0, ceil(_total_count_::float
                                       / (select count(*)
                                          from street_names)::float)::integer)
    order by random()
  ), cities_source as (
    select city, zip, state, row_number() over ()
    from cities
    cross join generate_series(0, ceil(_total_count_::float
                                       / (select count(*)
                                          from cities)::float)::integer)
    order by random()
  ), languages_source as (
    select code as language_code,
           name as language_name,
           row_number() over ()
    from languages
    cross join generate_series(0, ceil(_total_count_::float
                                       / (select count(*)
                                          from languages)::float)::integer)
    order by random()
  ), organizations_source as (
    select id as organization_id,
           resource#>>'{name}' as organization_name,
           row_number() over ()
    from organization
    cross join generate_series(0, ceil(_total_count_::float
                                       / (select count(*)
                                          from organization)::float)::integer)
    order by random()
  ), patient_data as (
    select
      *,
      random_date() as birth_date,
      random_phone() as phone
    from first_names_source
    join last_names_source using (row_number)
    join street_names_source using (row_number)
    join cities_source using (row_number)
    join languages_source using (row_number)
    join organizations_source using (row_number)
  ), inserted as (
    INSERT into patient (id, version_id, resource)
    SELECT obj->>'id', obj#>>'{meta,versionId}', obj
    FROM (
      SELECT
        json_build_object(
         'resourceType', 'Patient',
         'id', gen_random_uuid(),
         'meta', json_build_object(
            'versionId', gen_random_uuid(),
            'lastUpdated', CURRENT_TIMESTAMP
          ),
         'gender', sex,
         'birthDate', birth_date,
         'active', TRUE,
         'name', ARRAY[
           json_build_object(
            'given', ARRAY[first_name],
            'family', ARRAY[last_name]
           )
         ],
         'telecom', ARRAY[
           json_build_object(
            'system', 'phone',
            'value', phone,
            'use', 'home'
           )
         ],
         'address', make_address(street_name, zip, city, state),
         'communication', ARRAY[
           json_build_object(
             'language',
             json_build_object(
               'coding', ARRAY[
                 json_build_object(
                   'system', 'urn:ietf:bcp:47',
                   'code', language_code,
                   'display', language_name
                 )
               ],
               'text', language_name
             ),
             'preferred', TRUE
           )
         ],
         'identifier', ARRAY[
           json_build_object(
             'use', 'usual',
             'system', 'urn:oid:2.16.840.1.113883.2.4.6.3',
             'value', random(6000000, 100000000)::text
           ),
           json_build_object(
             'use', 'usual',
             'system', 'urn:oid:1.2.36.146.595.217.0.1',
             'value', random(6000000, 100000000)::text,
             'label', 'MRN'
           )
         ],
         'managingOrganization', json_build_object(
           'reference', 'Organization/' || organization_id,
           'display', organization_name
         )
        )::jsonb as obj
        FROM patient_data
        LIMIT _total_count_
    ) _
    RETURNING id
  )
  select count(*) inserted;
$$ LANGUAGE SQL;

\echo 'Create generation function: "insert_encounters()".'
DROP FUNCTION IF EXISTS insert_encounters() CASCADE;
CREATE OR REPLACE FUNCTION insert_encounters()
RETURNS bigint AS $$
  WITH patients_ids_source as (
    SELECT id as patient_id,
           row_number() over ()
      FROM patient

    UNION ALL

    SELECT patient_id, row_number() over ()
    FROM (SELECT id as patient_id
          FROM patient order by random()
          LIMIT (select count(*) from patient) / 3) _
  ), practitioners_source AS (
    SELECT id as practitioner_id,
           row_number() OVER ()
    FROM practitioner
    CROSS JOIN generate_series(0, ceil((select count(*) from patients_ids_source)::float
                                       / (select count(*)
                                          from practitioner)::float)::integer)
    ORDER by random()
  ), encounter_data as (
    SELECT *,
           random_elem(ARRAY['inpatient',
                             'outpatient',
                             'ambulatory',
                             'emergency']) as class,
           random_elem(ARRAY['in-progress',
                             'planned',
                             'arrived',
                             'onleave',
                             'cancelled',
                             'finished']) as status
    FROM patients_ids_source
    JOIN practitioners_source using (row_number)
  ), inserted as (
    INSERT into encounter (id, version_id, resource)
    SELECT obj->>'id', obj#>>'{meta,versionId}', obj
    FROM (
      SELECT
        json_build_object(
         'resourceType', 'Encounter',
         'id', gen_random_uuid(),
         'status', status,
         'class', class,
         'patient', json_build_object(
           'reference', 'Patient/' || patient_id
         ),
         'participant', ARRAY[
           json_build_object(
             'individual', json_build_object(
               'reference', 'Practitioner/' || practitioner_id
             )
           )
         ]
        )::jsonb as obj
        FROM encounter_data
    ) _
    RETURNING id
  )
  SELECT 42::bigint;
$$ LANGUAGE SQL;

\echo 'Create generation function: "generate(_number_of_patients_ integer, _number_of_practitioners_ integer, _rand_seed_ float)".'
DROP FUNCTION IF EXISTS generate(_number_of_patients_ integer,
                                 _number_of_practitioners_ integer,
                                 _rand_seed_ float) CASCADE;
CREATE OR REPLACE FUNCTION generate(_number_of_patients_ integer,
                                    _number_of_practitioners_ integer,
                                    _rand_seed_ float)
RETURNS bigint AS $$
  BEGIN
    TRUNCATE TABLE organization, organization_history,
                   encounter, encounter_history,
                   practitioner, practitioner_history,
                   patient, patient_history;
    PERFORM insert_organizations();
    PERFORM insert_practitioners(_number_of_practitioners_);
    PERFORM insert_patients(_number_of_patients_);
    PERFORM insert_encounters();
  RETURN (SELECT count(*) FROM patient);
  END
$$ LANGUAGE plpgsql;
