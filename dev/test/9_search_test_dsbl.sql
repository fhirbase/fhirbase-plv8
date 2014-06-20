--db:fhirb
--{{{
select regexp_split_to_table from regexp_split_to_table('a,b,c', ',');
--}}}
--{{{
    SELECT parse_search_params('Patient', $JSON${
      "name": "Chalmers",
      "given": "Peter",
      "active": "true",
      "gender": "http://hl7.org/fhir/v3/AdministrativeGender|M"
    }$JSON$);
--}}}

--{{{
    SELECT parse_search_params('Patient','{}'::jsonb);
--}}}
--{{{
select * from patient_search_string
--}}}

--{{{
SELECT
  search_resource('Patient',
    $JSON${
        "name": "Donald",
        "given": "Du"
    }$JSON$)

--}}}
--{{{
 SELECT '2013-01-14T10:00+0600'::timestamp;
 SELECT '2013-01-14T10:00+0600'::timestamptz;
 SELECT '2013-01-14T10:00Z'::timestamptz;
--}}}

--{{{
SELECT
  history_resource('Patient',
    (select logical_id from patient limit 1))

--}}}

--{{{
  SELECT  'SELECT ? FROM '
  || string_agg((x.row)->>'param' || '_idx', ',')
  || ' WHERE '
  FROM (
    SELECT json_array_elements($JSON$[
     {"param":"given", "value":["peter", "wolf"], "modificator": "exact"},
     {"param":"given", "value":["peter"], "modificator": "exact"},
     {"param":"telecom", "value":["work"]}
    ]$JSON$::json) as row
  ) x;
--}}}

--{{{
SELECT * from
patient_search_string s1,
patient_search_string s2
where
s1.param='given' and s1.value ilike 'peter%'
and s1.resource_id = s2.resource_id  and s2.param = 'telecom' and s2.value ilike '%home%'
--group by s1.resource_id


--}}}
