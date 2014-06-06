--db:fhirb
--{{{
select * from fhir.resource_indexables
order by resource_type
;
--}}}

SELECT * FROM index_string_complex_type(
  '{Patient,address}',
  $JSON$
    {
      "use": "home",
      "line": [
        "534 Erewhon St"
      ],
      "city": "PleasantVille",
      "state": "Vic",
      "zip": "3999"
    }
  $JSON$
);

--{{{
\set pt `curl http://www.hl7.org/implement/standards/fhir/patient-example.json`

SELECT unnest(index_string_resource(:'pt'::jsonb));
--}}}

--{{{
\set subj `curl http://www.hl7.org/implement/standards/fhir/relatedperson-example-f002-ariadne.json`

SELECT unnest(index_string_resource(:'subj'::jsonb));
--}}}

--{{{
create extension pgcrypto;
select gen_random_uuid();
--}}}

--{{{
\set pt `curl http://www.hl7.org/implement/standards/fhir/patient-example.json`

delete from patient_search_string;
delete from patient;
SELECT insert_resource(:'pt'::jsonb);
select * from patient_search_string;
select * from patient;
--}}}
--{{{
select DISTINCT(type) from fhir.resource_indexables
where search_type = 'token'
and param_name <> '_id';

select * from fhir.resource_indexables
where search_type = 'token'
and param_name <> '_id';
--}}}
--{{{
\d patient_search_token
--}}}
