--db:fhirplace
--{{{
\timing

CREATE OR REPLACE
FUNCTION _generate_observations()
RETURNS bigint
language sql AS $$

WITH inserted as (
  INSERT INTO observation (content)
  RETURNING logical_id
)
SELECT count(*) FROM inserted;
$$;
--}}}
--{{{
SELECT
format($JSON$
 {
   "resourceType":"Observation",
   "subject": %s,
   "name": %s,
   "valueQuantity": %s
 }
$JSON$,
subject,
name,
value
)
FROM
(
  SELECT
  json_build_object(
    'reference', ('Patient/' || logical_id)
  ) as subject,
  json_build_object(
    'text', l.loinc_short_name,
    'coding', ARRAY[
       json_build_object(
          'system', 'http://loinc.org',
          'code', l.loinc,
          'display', l.loinc_name
       ),
       json_build_object(
          'system', 'http://localhost',
          'code', l.code,
          'display', l.label
       )
     ]
  ) as name,
  json_build_object(
    'value', random()*200,
    'units', l.units,
    'code', l.units,
    'system', 'http,//unitsofmeasure.org'
  ) as value
  FROM patient p
  JOIN ( SELECT * FROM gen.labs l ORDER BY (freq*random()::real) desc LIMIT 10) l ON true = true
  LIMIT 100
) _
--}}}

--{{{
SELECT 0.5*random()
--}}}
