-- #import ./load_data.sql
-- #import ../src/jsonbext.sql

proc! create_patients(_limit_ integer) RETURNS void
  BEGIN
    RAISE NOTICE 'Create patients';
    PERFORM count(crud.create('{}'::jsonb,
                              jsonbext.dissoc(patients.content, 'id')))
            FROM (SELECT content FROM patient LIMIT _limit_) patients;

proc! read_patients(_limit_ integer) RETURNS void
  BEGIN
    RAISE NOTICE 'Read patients';
    PERFORM count(crud.read('{}'::jsonb, patients.logical_id))
            FROM (SELECT logical_id FROM patient LIMIT _limit_) patients;

proc! create_temporary_patients(_limit_ integer) RETURNS void
  BEGIN
    RAISE NOTICE 'Create temporary patients for update';
    DROP TABLE IF EXISTS temp.patient_data;
    CREATE TABLE temp.patient_data (data jsonb);
    INSERT INTO temp.patient_data (data)
           SELECT jsonbext.merge(content,
                                  '{"multipleBirthBoolean": true}'::jsonb)
           FROM patient LIMIT _limit_;

proc! update_patients(_limit_ integer) RETURNS void
  BEGIN
    RAISE NOTICE 'Update patients';
    PERFORM crud.update('{}'::jsonb, temp_patients.data)
            FROM
            (SELECT data FROM temp.patient_data LIMIT _limit_) temp_patients;

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
