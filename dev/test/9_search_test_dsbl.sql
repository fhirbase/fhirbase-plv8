--db:fhirb
--{{{
\timing
select * from fhir.resource_indexables
limit 10;
--}}}
--{{{
\timing

    SELECT build_search_query('Patient','{}');
--}}}
--{{{
    SELECT build_search_query('Patient', $JSON${
      "provider.partof.name": "hl"
    }$JSON$);
--}}}
--{{{
    SELECT build_search_query('Patient', $JSON${
      "provider.partof.name": "hl",
      "name": "Chalmers",
      "given": "Peter",
      "provider.name": "hl",
      "active": "true",
      "gender": "http://hl7.org/fhir/v3/AdministrativeGender|M"
    }$JSON$);

    SELECT search('Patient', $JSON${
      "provider.partof.name": "hl",
      "name": "Chalmers",
      "given": "Peter",
      "provider.name": "hl",
      "active": "true",
      "gender": "http://hl7.org/fhir/v3/AdministrativeGender|M"
    }$JSON$);
--}}}
--{{{
\set js '{"date":"now","status": "active", "subject.provider.name": "hl", "subject.name": "Peter", "indication:Observation.name": "loinc"}'


SEleCT COALESCE(split_part('a', '.',2), 'ups');

CREATE OR REPLACE
FUNCTION get_reference_type(_key text,  _types text[])
RETURNS text language sql AS $$
    SELECT
        CASE WHEN position(':' in _key ) > 0 THEN
           split_part(_key, ':', 2)
        WHEN array_length(_types, 1) = 1 THEN
          _types[1]
        ELSE
          null -- TODO: think about this case
        END
$$ IMMUTABLE;

WITH RECURSIVE params(parent_res, res, path, key, value) AS (
SELECT
  null::text as parent_res,
  'Encounter'::text as res
  ,'{Encounter}'::text[] as path
  ,x.key
  ,x.value
  FROM jsonb_each_text(:'js') x
UNION

SELECT
    res as parent_res,
    get_reference_type(split_part(x.key, '.', 1), re.ref_type) as res,
    array_append(x.path,split_part(key, '.', 1)) as path,
    (regexp_matches(key, '^([^.]+)\.(.+)'))[2] AS key,
    value
    FROM params x
JOIN fhir.resource_indexables ri
     ON ri.param_name = split_part(split_part(x.key, '.', 1), ':',1)
    AND ri.resource_type = x.res
JOIN fhir.resource_elements re
    ON re.path = ri.path
)

SELECT * FROM
(
  -- params
  (SELECT 'index_join' as tp, p.res, p.path, p.key, p.value
     FROM params p WHERE position('.' in p.key) = 0)

  UNION ALL
  -- references

  (SELECT 'ref_join' as tp, res, path, p.parent_res as key, p.res as value
    FROM params p
    WHERE parent_res is not null
    GROUP BY p.parent_res, res, path)
) _
ORDER BY path
LIMIT 100
;



--}}}

--{{{
select * from fhir.resource_indexables
where
resource_type = 'Encounter'
and param_name = 'status'
--}}}
/* --{{{ */
/* select * from patient_search_string */
/* --}}} */

/* --{{{ */
/* SELECT */
/*   search_resource('Patient', */
/*     $JSON${ */
/*         "name": "Donald", */
/*         "given": "Du" */
/*     }$JSON$) */

/* --}}} */
/* --{{{ */
/*  SELECT '2013-01-14T10:00+0600'::timestamp; */
/*  SELECT '2013-01-14T10:00+0600'::timestamptz; */
/*  SELECT '2013-01-14T10:00Z'::timestamptz; */
/* --}}} */

/* --{{{ */
/* SELECT */
/*   history_resource('Patient', */
/*     (select logical_id from patient limit 1)) */

/* --}}} */

/* --{{{ */
/*   SELECT  'SELECT ? FROM ' */
/*   || string_agg((x.row)->>'param' || '_idx', ',') */
/*   || ' WHERE ' */
/*   FROM ( */
/*     SELECT json_array_elements($JSON$[ */
/*      {"param":"given", "value":["peter", "wolf"], "modificator": "exact"}, */
/*      {"param":"given", "value":["peter"], "modificator": "exact"}, */
/*      {"param":"telecom", "value":["work"]} */
/*     ]$JSON$::json) as row */
/*   ) x; */
/* --}}} */

/* --{{{ */
/* SELECT * from */
/* patient_search_string s1, */
/* patient_search_string s2 */
/* where */
/* s1.param='given' and s1.value ilike 'peter%' */
/* and s1.resource_id = s2.resource_id  and s2.param = 'telecom' and s2.value ilike '%home%' */
/* --group by s1.resource_id */


/* --}}} */
