--db:fhirb
--{{{
\set pt `curl http://www.hl7.org/implement/standards/fhir/observation-example-f001-glucose.json`

SELECT insert_resource(:'pt'::jsonb);
select * from observation_search_quantity;
--}}}
--{{{
/* select * from fhir.resource_search_params */
/* where path[1] = 'Observation' */
/* ; */
select * from fhir.resource_indexables
where resource_type = 'Observation';
--}}}

--{{{
select * from fhir.primitive_types
order by type

--}}}
--{{{
select * from fhir.expanded_resource_elements
where
path[1] = 'Observation'
and path[2] = 'subject'
order by path
;
--}}}
