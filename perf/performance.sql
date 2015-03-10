-- #import ./perf_schema.sql
func gen_rand(_a_ text, _b_ text, _mod_ integer) RETURNS text
 SELECT lpad(
   (mod(ascii(_a_) +  ascii(_b_), _mod_) + 1)::text, 2, '0'
 )

-- TODO: improve generator
--       improve patient resource (add adress etc.)
--       add more resources (encounter, order etc.)
func! generate_patient(_total_count_ integer, _offset_ integer) RETURNS bigint
  with x as (
    select * from temp.human_names_and_lastnames
     -- order by percent desc
     offset _total_count_ * _offset_
     LIMIT _total_count_
  ), names as (
    select x.name as given_name,
           x.family as family_name,
           x.sex as gender,
           '1970'
           || '-'
           || this.gen_rand(x.name, x.family, 12)
           || '-'
           || this.gen_rand(x.name, x.family, 28)
          as birthDate
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
         'birthDate', birthDate,
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
\set perf_patient_limit `echo $perf_patient_limit`
\set perf_patient_offset `echo $perf_patient_offset`
select this.generate_patient((:'perf_patient_limit')::int, (:'perf_patient_offset')::int);
select count(*) from patient;

-- -- select 'search by created patients'
-- SELECT fhir.search('Patient', 'name=John');

select admin.admin_disk_usage_top(10);
