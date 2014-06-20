--db:fhirb
--{{{
\set pt `curl http://www.hl7.org/implement/standards/fhir/observation-example-f001-glucose.json`

SELECT insert_resource(:'pt'::jsonb, '[{"scheme":"sch","term":"term", "label":"label"}]'::jsonb);
select * from observation_search_quantity;
--}}}
--{{{
select tags();
select tags('Observation');
select tags('Observation', gen_random_uuid());
select tags('Observation', gen_random_uuid(), gen_random_uuid());
--}}}
