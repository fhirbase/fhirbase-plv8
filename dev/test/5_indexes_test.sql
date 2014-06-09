--db:fhirb

--{{{
\set pt `curl http://www.hl7.org/implement/standards/fhir/patient-example.json`

SELECT unnest(index_token_resource(:'pt'::jsonb));
--}}}

--{{{

select ('{}'::jsonb->>'ups') is null;
--}}}

--{{{
SELECT * FROM index_identifier_to_token(
  $JSON$
  {
    "use": "usual",
    "system": "urn:oid:2.16.840.1.113883.2.4.6.3",
    "value": "738472983"
  }
  $JSON$
);
--}}}

--{{{
SELECT * FROM index_coding_to_token(
  $JSON$
  {
    "system": "urn:ietf:bcp:47",
    "code": "nl",
    "display": "Dutch"
  }
  $JSON$
);
--}}}

--{{{
SELECT * FROM unnest(index_codeable_concept_to_token(
  $JSON$
  {
  "coding": [
  {
  "system": "urn:ietf:bcp:47",
  "code": "nl",
  "display": "Dutch"
  }
  ],
  "text": "Nederlands"
  }
  $JSON$
));
--}}}

--{{{
select * from fhir.resource_indexables
where type = '_NestedResource_'
;
--}}}


--{{{
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
--}}}


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
delete from patient_search_token;
delete from patient_history;
delete from patient;

SELECT insert_resource(:'pt'::jsonb);
select update_resource(logical_id, data) FROM patient;

select * from patient_search_token;
select * from patient_search_string;
select * from patient;
select * from patient_history;

--}}}

--{{{
\set subj  `curl http://www.hl7.org/implement/standards/fhir/encounter-example-f002-lung.json`

delete from encounter_search_string;
delete from encounter_search_token;
delete from encounter;
\timing
SELECT insert_resource(:'subj'::jsonb);
select * from encounter_search_token;
select * from encounter;

--}}}



--{{{
select DISTINCT(type) from fhir.resource_indexables
where search_type = 'token'
and param_name <> '_id';
--}}}
--{{{
\d patient_search_token
--}}}
