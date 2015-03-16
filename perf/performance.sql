-- #import ./perf_schema.sql

func! random(a numeric, b numeric) RETURNS numeric
  SELECT ceil(a + (b - a) * random())::numeric;

func random_elem(a anyarray) RETURNS anyelement
  SELECT a[floor(RANDOM() * array_length(a, 1))];

func! random_date() RETURNS text
  SELECT this.random(1900, 2010)::text
           || '-'
           || lpad(this.random(1, 12)::text, 2, '0')
           || '-'
           || lpad(this.random(1, 28)::text, 2, '0');

func! random_phone() RETURNS text
  SELECT '+' || this.random(1, 12)::text ||
         ' (' || this.random(1, 999)::text || ') ' ||
         lpad(this.random(1, 999)::text, 3, '0') ||
         '-' ||
         lpad(this.random(1, 99)::text, 2, '0') ||
         '-' ||
         lpad(this.random(1, 99)::text, 2, '0')

func make_address(_street_name_ text, _zip_ text, _city_ text, _state_ text) RETURNS jsonb
  select array_to_json(ARRAY[
    json_build_object(
      'use', 'home',
      'line', ARRAY[_street_name_ || ' ' || this.random(0, 100)::text],
      'city', _city_,
      'postalCode', _zip_::text,
      'state', _state_,
      'country', 'US'
    )
  ])::jsonb;

func! insert_organizations() RETURNS bigint
  with organizations_source as (
    select organization_name, row_number() over () from temp.organization_names
    order by random()
  ), street_names_source as (
    select street_name, row_number() over () from temp.street_names
    order by random()
  ), cities_source as (
    select city, zip, state, row_number() over () from temp.cities
    order by random()
  ), organization_data as (
    select *,
           this.random_phone() as phone
    from organizations_source
    join street_names_source using (row_number)
    join cities_source using (row_number)
  ), inserted as (
    INSERT into organization (logical_id, version_id, content)
    SELECT obj->>'id', obj#>>'{meta,versionId}', obj
    FROM (
      SELECT
        json_build_object(
         'id', gen_random_uuid(),
         'name', organization_name,
         'telecom', ARRAY[
           json_build_object(
            'system', 'phone',
            'value', phone,
            'use', 'work'
           )
         ],
         'address', this.make_address(street_name, zip, city, state)
        )::jsonb as obj
        FROM organization_data
    ) _
    RETURNING logical_id
  )
  select count(*) inserted;

-- TODO: improve generator
--       improve patient resource (add adress etc.)
--       add more resources (encounter, order etc.)
func! insert_patients(_total_count_ integer, _offset_ integer) RETURNS bigint
  with first_names_source as (
    select CASE WHEN sex = 'M' THEN 'male' ELSE 'female' END as sex,
           first_name,
           row_number() over () from temp.first_names
    cross join generate_series(0, ceil(_total_count_::float
                                        / (select count(*) from temp.first_names)::float)::integer)
    order by random()
  ), last_names_source as (
    select last_name, row_number() over () from temp.last_names
    cross join generate_series(0, ceil(_total_count_::float
                                        / (select count(*) from temp.last_names)::float)::integer)
    order by random()
  ), street_names_source as (
    select street_name, row_number() over () from temp.street_names
    cross join generate_series(0, ceil(_total_count_::float
                                        / (select count(*) from temp.street_names)::float)::integer)
    order by random()
  ), cities_source as (
    select city, zip, state, row_number() over () from temp.cities
    cross join generate_series(0, ceil(_total_count_::float
                                        / (select count(*) from temp.cities)::float)::integer)
    order by random()
  ), languages_source as (
    select code as language_code,
           name as language_name,
           row_number() over () from temp.languages
    cross join generate_series(0, ceil(_total_count_::float
                                        / (select count(*) from temp.languages)::float)::integer)
    order by random()
  ), patient_data as (
    select
      *,
      this.random_date() as birth_date,
      this.random_phone() as phone
    from first_names_source
    join last_names_source using (row_number)
    join street_names_source using (row_number)
    join cities_source using (row_number)
    join languages_source using (row_number)
  ), inserted as (
    INSERT into patient (logical_id, version_id, content)
    SELECT obj->>'id', obj#>>'{meta,versionId}', obj
    FROM (
      SELECT
        json_build_object(
         'id', gen_random_uuid(),
         'meta', json_build_object(
            'versionId', gen_random_uuid(),
            'lastUpdated', CURRENT_TIMESTAMP
          ),
         'resourceType', 'Patient',
         'gender', sex,
         'birthDate', birth_date,
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
         'address', this.make_address(street_name, zip, city, state),
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
             'value', this.random(6000000, 100000000)::text
           ),
           json_build_object(
             'use', 'usual',
             'system', 'urn:oid:1.2.36.146.595.217.0.1',
             'value', this.random(6000000, 100000000)::text,
             'label', 'MRN'
           )
         ]
        )::jsonb as obj
        FROM patient_data
        LIMIT _total_count_
    ) _
    RETURNING logical_id
  )
  select count(*) inserted;

\timing
\set batch_size `echo $batch_size`
\set batch_number `echo $batch_number`
\set rand_seed `echo ${rand_seed:-0.321}`

SELECT setseed(:'rand_seed'::float);

-- select count(*) from patient;

-- SELECT fhir.search('Patient', 'name=John');

-- SELECT indexing.index_search_param('Patient','name');
-- SELECT fhir.search('Patient', 'name=John');

-- select admin.admin_disk_usage_top(10);
