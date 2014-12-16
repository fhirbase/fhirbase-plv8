--db:fhirplace
--{{{
\timing

CREATE OR REPLACE
FUNCTION _generate_pt()
RETURNS bigint
language sql AS $$

WITH inserted as (
  INSERT INTO patient (content)
SELECT
format('{"resourceType":"Patient", "name": [%s], "birthDate": "%s", "active": %s, "gender": {"coding":[%s]}, "identifier": [{"use": "official","label": "Local","system": "acme.com", "value": "%s"},{"use": "usual","label": "MRN","system": "urn:oid:1.2.36.146.595.217.0.1", "value": "%s"}]}',
  name,
  birthdate,
  active,
  gender,
  local_id,
  mrn
)::jsonb
FROM (
  SELECT
  json_build_object(
    'use', 'official',
    'family', ARRAY[x.name],
    'given', ARRAY[y.name]
  )::jsonb as name,
  date(
    (current_timestamp - '100 years'::interval) +
    trunc(random() * 365) * '1 day'::interval +
    trunc(random() * 100) * '1 year'::interval
  ) as birthdate,
  case when random() < 0.03 then 'false' else 'true' end as active,
  case when x.sex = 'f' then
    '{"system": "http://hl7.org/fhir/v3/AdministrativeGender", "code": "M", "display": "Male"}'
  else
    '{"system": "http://hl7.org/fhir/v3/AdministrativeGender", "code": "F", "display": "Female"}'
  end as gender,
  substring((gen_random_uuid())::text for 8) as local_id,
  substring((gen_random_uuid())::text for 8) as mrn
  FROM (
    SELECT name, sex, row_number() OVER (ORDER BY random()) AS rn
    FROM gen.family
  ) x
  JOIN (
    SELECT name, sex, row_number() OVER (ORDER BY random()) AS rn
    FROM gen.given
  ) y ON x.rn = y.rn AND x.sex = y.sex
  JOIN (
    SELECT name, sex, row_number() OVER (ORDER BY random()) AS rn
    FROM gen.middle
  ) z ON x.rn = z.rn AND x.sex = z.sex
) _
  RETURNING logical_id
)
SELECT count(*) FROM inserted;
$$;
--}}}
