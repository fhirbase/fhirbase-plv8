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


func gen_rand(_a_ text, _b_ text, _mod_ integer) RETURNS text
 SELECT lpad(
   (mod(ascii(_a_) +  ascii(_b_), _mod_) + 1)::text, 2, '0'
 )

select fhir.generate_tables('{Patient}');

func! generate_pt(_limit_ integer) RETURNS bigint
  with x as (
    select *, row_number() over () from (
      select * from temp.human_names
       order by year
    ) _
  ), y as (
    select *, row_number() over () from (
      select * from temp.human_names
       order by percent
    ) _
  ), names as (
    select x.name as given_name,
           y.name || substring(reverse(lower(x.name)) from 1 for 3) as family_name,
           CASE WHEN x.sex = 'boy' THEN 'male' ELSE 'female' END as gender,
           (x.year::int + y.year::int)/2
           || '-'
           || this.gen_rand(x.name,y.name, 12)
           || '-'
           || this.gen_rand(x.name,y.name, 28)
          as birthDate
    from x
    join y on x.row_number = y.row_number
  ), inserted as (
    INSERT into patient (logical_id, version_id, content)
    SELECT obj->'id', obj->>'{meta,versionId}', obj
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
        LIMIT _limit_
    ) _
    RETURNING logical_id
  )
  select count(*) inserted;


\timing
select this.generate_pt(10000);
select count(*) from patient;
select admin.admin_disk_usage_top(10);
