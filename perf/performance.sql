-- #import ./perf_schema.sql

func! random(a numeric, b numeric) RETURNS numeric
  SELECT ceil(a + (b - a) * random())::numeric;

func! random_date() RETURNS text
  SELECT this.random(1900, 2010)::text
           || '-'
           || lpad(this.random(1, 12)::text, 2, '0')
           || '-'
           || lpad(this.random(1, 28)::text, 2, '0');

-- func gen_rand(_a_ text, _b_ text, _mod_ integer) RETURNS text
--  SELECT lpad(
--    (mod(ascii(_a_) +  ascii(_b_), _mod_) + 1)::text, 2, '0'
--  )

-- TODO: improve generator
--       improve patient resource (add adress etc.)
--       add more resources (encounter, order etc.)
func! insert_patients(_total_count_ integer, _offset_ integer) RETURNS bigint
  WITH x as (
    SELECT * from temp.patient_names
     OFFSET _offset_
     LIMIT _total_count_
  ), names as (
    select x.first_name as given_name,
           x.last_name as family_name,
           x.sex as gender,
           this.random_date() as birth_date
    from x
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
         'gender', gender,
         'birthDate', birth_date,
         'name', ARRAY[
           json_build_object(
            'given', ARRAY[given_name],
            'family', ARRAY[family_name]
           )
         ]
        )::jsonb as obj
        FROM names
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

-- select this.insert_patients((:'batch_size')::int,
--                              (:'batch_number')::int);
-- select count(*) from patient;

-- SELECT fhir.search('Patient', 'name=John');

-- SELECT indexing.index_search_param('Patient','name');
-- SELECT fhir.search('Patient', 'name=John');

-- select admin.admin_disk_usage_top(10);
