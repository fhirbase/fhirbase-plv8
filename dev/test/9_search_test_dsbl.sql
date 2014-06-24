--db:fhirb
--{{{
/* \timing */
/* select * from fhir.resource_indexables */
/* limit 10; */
/* --}}} */
/* --{{{ */
/* \timing */

/*     SELECT build_search_query('Patient','{}'); */
/* --}}} */
/* --{{{ */
/*     SELECT build_search_query('Patient', $JSON${ */
/*       "provider.partof.name": "hl" */
/*     }$JSON$); */
/* --}}} */
/* --{{{ */
/*     SELECT search('Patient', $JSON${ */
/*       "provider.partof.name": "hl", */
/*       "name": "Chalmers", */
/*       "given": "Peter", */
/*       "provider.name": "hl", */
/*       "active": "true", */
/*       "gender": "http://hl7.org/fhir/v3/AdministrativeGender|M" */
/*     }$JSON$); */

/*     /1* SELECT search('Patient', $JSON${ *1/ */
/*     /1*   "provider.partof.name": "hl", *1/ */
/*     /1*   "name": "Chalmers", *1/ */
/*     /1*   "given": "Peter", *1/ */
/*     /1*   "provider.name": "hl", *1/ */
/*     /1*   "active": "true", *1/ */
/*     /1*   "gender": "http://hl7.org/fhir/v3/AdministrativeGender|M" *1/ */
/*     /1* }$JSON$); *1/ */
/* --}}} */
--{{{
\timing
\set js '{"date":"1900-01-01","status": "active", "subject.provider.name": "hl", "subject.name": "Peter", "indication:Observation.name": "loinc"}'

SELECT search('Encounter', :'js');
--SELECT build_search_query('Encounter', '{}');
--}}}
