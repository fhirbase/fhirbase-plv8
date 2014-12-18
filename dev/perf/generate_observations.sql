--db:fhirplace
--{{{
\timing

CREATE OR REPLACE
FUNCTION _generate_observations(_num_per_pt integer)
RETURNS bigint
language sql AS $$

WITH inserted as (
  INSERT INTO observation (content)
  SELECT
  format($JSON$
   {
     "resourceType":"Observation",
     "text": {"status": "generated", "div": "<div></div>"},
     "subject": %s,
     "name": %s,
     "valueQuantity": %s,
     "referenceRange": [%s],
     "issued": "%s"
   }
  $JSON$,
  subject,
  name,
  value,
  referenceRange,
  issued
  )::jsonb
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
      'value', CASE
         WHEN delta IS NOT NULL THEN range_min + random()*delta
         WHEN range_max IS NOT NULL THEN range_max - random()*range_max/5
         WHEN range_min IS NOT NULL THEN range_min + random()*range_min/5
         ELSE 100 + random()*10
       END,
      'units', l.units,
      'code', l.units,
      'system', 'http://unitsofmeasure.org'
    ) as value,
    CASE
       WHEN delta IS NOT NULL
         THEN json_build_object(
          'low', json_build_object(
            'value', range_min,
            'units', range_units,
            'code', range_units,
            'system', 'http://unitsofmeasure.org'
          ),
          'high', json_build_object(
            'value', range_max,
            'units', range_units,
            'code', range_units,
            'system', 'http://unitsofmeasure.org'
          )
         )::text
       WHEN range_max IS NOT NULL
         THEN json_build_object(
          'high', json_build_object(
            'value', range_max,
            'units', range_units,
            'code', range_units,
            'system', 'http://unitsofmeasure.org'
          )
         )::text
       WHEN range_min IS NOT NULL
         THEN json_build_object(
          'low', json_build_object(
            'value', range_max,
            'units', range_units,
            'code', range_units,
            'system', 'http://unitsofmeasure.org'
          )
         )::text
       ELSE ''
    END as referenceRange,
    to_char(current_timestamp - ('5 year'::interval)*random(),'YYYY-MM-DD HH24:MI:SS')::text as issued

    FROM patient p
    JOIN (
      SELECT *,
      CASE WHEN range_min IS NOT NULL AND range_max IS NOT NULL THEN
        (range_max - range_min)
      ELSE
        NULL
      END as delta
      FROM gen.labs l
      ORDER BY (freq*random()::real) desc LIMIT _num_per_pt
    ) l ON true = true
  ) _
  RETURNING logical_id
)
SELECT count(*) FROM inserted;
$$;
--}}}
