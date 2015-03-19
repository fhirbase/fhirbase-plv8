-- #import ./load_data.sql
-- #import ../src/jsonbext.sql

proc! create_patient() RETURNS void
  BEGIN
    RAISE NOTICE 'Create patient';
    PERFORM count(crud.create('{}'::jsonb,
                              jsonbext.dissoc(patients.content, 'id')))
            FROM (SELECT content FROM patient LIMIT 1) patients;

proc! create_1000_patients() RETURNS void
  BEGIN
    RAISE NOTICE 'Create 1000 patients';
    PERFORM count(crud.create('{}'::jsonb,
                              jsonbext.dissoc(patients.content, 'id')))
            FROM (SELECT content FROM patient LIMIT 1000) patients;

proc! read_patient() RETURNS void
  BEGIN
    RAISE NOTICE 'Read patient';
    PERFORM count(crud.read('{}'::jsonb, patients.logical_id))
            FROM (SELECT logical_id FROM patient LIMIT 1) patients;

proc! read_1000_patients() RETURNS void
  BEGIN
    RAISE NOTICE 'Read 1000 patients';
    PERFORM count(crud.read('{}'::jsonb, patients.logical_id))
            FROM (SELECT logical_id FROM patient LIMIT 1) patients;

proc! create_temp_patients_for_update() RETURNS void
  BEGIN
    RAISE NOTICE 'Create temporary patients';
    DROP TABLE IF EXISTS temp.patient_data;
    CREATE TABLE temp.patient_data (data jsonb);
    INSERT INTO temp.patient_data (data)
           SELECT jsonbext.merge(content,
                                  '{"multipleBirthBoolean": true}'::jsonb)
           FROM patient LIMIT 1000;

proc! update_patient() RETURNS void
  BEGIN
    RAISE NOTICE 'Update patient';
    PERFORM crud.update('{}'::jsonb, temp_patients.data)
            FROM
            (SELECT data FROM temp.patient_data limit 1) temp_patients;

-- FIXME: Takes to many time!
proc! update_1000_patients() RETURNS void
  BEGIN
    RAISE NOTICE 'Update 1000 patients';
    PERFORM count(crud.update('{}'::jsonb,
                  jsonbext.assoc('{"resourceType": "Patient", "text": {"status": "generated", "div": "<div>!-- Snipped for Brevity --></div>"}, "extension": [{"url": "http://hl7.org/fhir/StructureDefinition/patient-birthTime", "valueInstant": "2001-05-06T14:35:45-05:00"}], "identifier": [{"use": "usual", "label": "MRN", "system": "urn:oid:1.2.36.146.595.217.0.1", "value": "12345", "period": {"start": "2001-05-06"}, "assigner": {"display": "Acme Healthcare"}}], "name": [{"use": "official", "family": ["Chalmers"], "given": ["Peter", "James"]}, {"use": "usual", "given": ["Jim"]}], "telecom": [{"use": "home"}, {"system": "phone", "value": "(03) 5555 6473", "use": "work"}], "gender": "male", "birthDate": "1974-12-25", "deceasedBoolean": false, "address": [{"use": "home", "line": ["534 Erewhon St"], "city": "PleasantVille", "state": "Vic", "postalCode": "3999"}], "contact": [{"relationship": [{"coding": [{"system": "http://hl7.org/fhir/patient-contact-relationship", "code": "partner"}]}], "name": {"family": ["du", "Marché"], "_family": [{"extension": [{"url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-qualifier", "valueCode": "VV"}]}, null], "given": ["Bénédicte"]}, "telecom": [{"system": "phone", "value": "+33 (237) 998327"}]}], "active": true}'::jsonb, 'id'::text, patients.content#>'{id}')))
            FROM (SELECT content FROM patient LIMIT 1000) patients;

proc! delete_patient() RETURNS void
  BEGIN
    RAISE NOTICE 'Delete patient';
    PERFORM count(crud.delete('{}'::jsonb, 'Patient', patients.logical_id))
            FROM (SELECT logical_id FROM patient LIMIT 1) patients;

proc! delete_1000_patients() RETURNS void
  BEGIN
    RAISE NOTICE 'Delete 1000 patients';
    PERFORM count(crud.delete('{}'::jsonb, 'Patient', patients.logical_id))
            FROM (SELECT logical_id FROM patient LIMIT 1000) patients;

proc! search_patient_with_many_search_candidates_with_limit_1000() RETURNS void
  BEGIN
    RAISE NOTICE 'Search patient by partial match without index and with many search candidates with limit 1000';
    PERFORM count(*) FROM fhir.search('Patient', 'name=John&_count=1000');

-- FIXME: Takes to many time!
proc! search_patient_for_a_nonexistent_value() RETURNS void
  BEGIN
    RAISE NOTICE 'Search Patient for a nonexistent value without index';
    PERFORM count(*) FROM fhir.search('Patient', 'name=nonexistentname');

-- FIXME: Takes to many time!
proc! search_patient_with_only_one_search_candidate() RETURNS void
  BEGIN
    RAISE NOTICE 'Search Patient by partial match without index and with only one search candidate';
    PERFORM count(crud.create('{}'::jsonb,
                  jsonbext.merge(jsonbext.dissoc(patients.content, 'id'),
                                 json_build_object(
                                   'name', ARRAY[
                                     json_build_object(
                                      'given', ARRAY['foobarbaz']
                                     )
                                   ]
                                 )::jsonb)))
            FROM (SELECT content FROM patient LIMIT 1) patients;
    PERFORM count(*)
            FROM fhir.search('Patient', 'name=foobarbaz&_count=50000000');

proc! search_patient_for_a_nonexistent_value() RETURNS void
  BEGIN
    RAISE NOTICE 'Search Patient for a nonexistent value using index';
    PERFORM count(*) FROM fhir.search('Patient', 'name=nonexistentname');

proc! search_patient_and_with_many_search_candidates() RETURNS void
  BEGIN
    RAISE NOTICE 'Search Patient by partial match using index and with many search candidates';
    PERFORM count(*)
            FROM fhir.search('Patient', 'name=John&_count=50000000');

proc! search_patient_with_only_one_search_candidate() RETURNS void
  BEGIN
    RAISE NOTICE 'Search Patient by partial match using index and with only one search candidate';
    PERFORM count(crud.create('{}'::jsonb,
                  jsonbext.merge(jsonbext.dissoc(patients.content, 'id'),
                                 json_build_object(
                                   'name', ARRAY[
                                     json_build_object(
                                      'given', ARRAY['foobarbazwithindex']
                                     )
                                   ]
                                 )::jsonb)))
            FROM (SELECT content FROM patient LIMIT 1) patients;
    PERFORM count(*) FROM fhir.search('Patient',
                                  'name=foobarbazwithindex&_count=50000000');

-- -- FIXME: Takes to many time!
-- SELECT indexing.index_search_param('Patient','birthdate');

-- -- FIXME: Takes to many time!
-- SELECT indexing.index_search_param('Patient','identifier');

proc! history_for_nonexistent_patient() RETURNS void
  BEGIN
    RAISE NOTICE 'History for nonexistent patient';
    PERFORM crud.history('{}'::jsonb, 'Patient', 'nonexistentid');

proc! history_for_one_patient() RETURNS void
  BEGIN
    RAISE NOTICE 'History for one patient';
    PERFORM count(crud.create('{}'::jsonb,
                              jsonbext.merge(patients.content,
                                             '{"id": "foo-bar-id"}'::jsonb)))
            FROM (SELECT content FROM patient LIMIT 1) patients;
    PERFORM crud.history('{}'::jsonb, 'Patient', 'foo-bar-id');

-- FIXME: Takes to many time and waste all disk space!
proc! history_for_all_patient() RETURNS void
  BEGIN
    RAISE NOTICE 'History for all patient';
    PERFORM count(crud.history('{}'::jsonb, 'Patient'));
