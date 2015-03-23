-- #import ./load_data.sql
-- #import ../src/jsonbext.sql

proc! create_patients(_limit_ integer) RETURNS void
  BEGIN
    RAISE NOTICE 'Create patients';
    PERFORM count(crud.create('{}'::jsonb,
                              jsonbext.dissoc(patients.content, 'id')))
            FROM (SELECT content FROM patient LIMIT _limit_) patients;

proc! create_patient_with_id(_id_ text) RETURNS void
  BEGIN
    RAISE NOTICE 'Create patient with id';
    DELETE FROM patient WHERE content#>>'{id}' = _id_;
    PERFORM count(crud.create('{}'::jsonb,
                              jsonbext.merge(patients.content,
                                             ('{"id": "' || _id_ || '"}')::jsonb)))
            FROM (SELECT content FROM patient LIMIT 1) patients;

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

proc! delete_patients(_limit_ integer) RETURNS void
  BEGIN
    RAISE NOTICE 'Delete patients';
    PERFORM count(crud.delete('{}'::jsonb, 'Patient', patients.logical_id))
            FROM (SELECT logical_id FROM patient LIMIT _limit_) patients;

proc! search_patient_with_only_one_search_candidate() RETURNS void
  BEGIN
    RAISE NOTICE 'Search Patient by partial match and with only one search candidate';
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

proc! index_search_param(_resource_type_ text, _name_ text) RETURNS void
  BEGIN
    PERFORM indexing.drop_index_search_param(_resource_type_, _name_);
    PERFORM indexing.index_search_param(_resource_type_, _name_);
