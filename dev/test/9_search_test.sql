--db:fhirb
--{{{
select regexp_split_to_table from regexp_split_to_table('a,b,c', ',');
--}}}
--{{{
    SELECT parse_search_params('Patient', $JSON${
      "name": "Chalmers",
      "given": "Peter"
    }$JSON$)
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
SELECT
  search_resource('Patient','{}');;

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
