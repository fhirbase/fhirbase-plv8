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
    SELECT search('Patient', $JSON${
      "provider.partof.name": "hl",
      "name": "Chalmers",
      "given": "Peter",
      "provider.name": "hl",
      "active": "true",
      "gender": "http://hl7.org/fhir/v3/AdministrativeGender|M"
    }$JSON$);

    /* SELECT search('Patient', $JSON${ */
    /*   "provider.partof.name": "hl", */
    /*   "name": "Chalmers", */
    /*   "given": "Peter", */
    /*   "provider.name": "hl", */
    /*   "active": "true", */
    /*   "gender": "http://hl7.org/fhir/v3/AdministrativeGender|M" */
    /* }$JSON$); */
--}}}
--{{{
\set js '{"date":"1900-01-01","status": "active", "subject.provider.name": "hl", "subject.name": "Peter", "indication:Observation.name": "loinc"}'

SELECT search('Encounter', :'js');
--}}}
--{{{
       SELECT DISTINCT(encounter.logical_id)
         FROM encounter encounter

           JOIN encounter_search_token encounter_token
             ON encounter_token.resource_id = encounter.logical_id
             AND
     ("encounter_token".param = 'status'
      AND (encounter_token.code = 'active'))


           JOIN encounter_search_date encounter_date
             ON encounter_date.resource_id = encounter.logical_id
             AND
     ("encounter_date".param = 'date'
      AND ('["1900-01-01 00:00:00+02:30","1900-01-01 23:59:59+02:30")'::tstzrange @> tstzrange(encounter_date."start", encounter_date."end")))


           JOIN observation_references encounter_indicationobservation
             ON encounter_indicationobservation.resource_id::varchar = encounter.logical_id::varchar

           JOIN observation_search_token encounter_indicationobservation_token
             ON encounter_indicationobservation_token.resource_id = encounter_indicationobservation.logical_id
             AND
     ("encounter_indicationobservation_token".param = 'name'
      AND (encounter_indicationobservation_token.code = 'loinc'))


           JOIN patient_references encounter_subject
             ON encounter_subject.resource_id::varchar = encounter.logical_id::varchar

           JOIN patient_search_string encounter_subject_string
             ON encounter_subject_string.resource_id = encounter_subject.logical_id
             AND
     ("encounter_subject_string".param = 'name'
      AND (encounter_subject_string.value ilike '%Peter%'))


           JOIN organization_references encounter_subject_provider
             ON encounter_subject_provider.resource_id::varchar = encounter_subject.logical_id::varchar

           JOIN organization_search_string encounter_subject_provider_string
             ON encounter_subject_provider_string.resource_id = encounter_subject_provider.logical_id
             AND
     ("encounter_subject_provider_string".param = 'name'
      AND (encounter_subject_provider_string.value ilike '%hl%'))












--}}}
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
