-- #import ./load_data.sql
-- #import ../src/jsonbext.sql

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Create Patient';
-- END
-- $$;

-- SELECT count(crud.create('{}'::jsonb, jsonbext.dissoc(patients.content, 'id'))) FROM
-- (SELECT content FROM patient LIMIT 1000) patients;

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Read Patient';
-- END
-- $$;

-- SELECT count(crud.read('{}'::jsonb, patients.logical_id)) FROM
-- (SELECT logical_id FROM patient LIMIT 1) patients;

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Update Patient';
-- END
-- $$;

-- drop table if exists temp.patient_data;
-- create table temp.patient_data (data jsonb);
-- insert into temp.patient_data (data)
-- select jsonbext.merge(content,
--                       '{"multipleBirthBoolean": true}'::jsonb)
-- from patient limit 1000;


-- SELECT crud.update('{}'::jsonb, temp_patients.data)
-- FROM
-- (SELECT data FROM temp.patient_data limit 1) temp_patients;

-- -- DO language plpgsql $$
-- -- BEGIN
-- --   RAISE NOTICE 'Update Patient';
-- -- END
-- -- $$;

-- -- select crud.update('{}'::jsonb, temp_patients.data)
-- -- from (select data from temp.patient_data) temp_patients;

-- -- SELECT count(crud.update('{}'::jsonb, jsonbext.assoc('{"resourceType": "Patient", "text": {"status": "generated", "div": "<div>!-- Snipped for Brevity --></div>"}, "extension": [{"url": "http://hl7.org/fhir/StructureDefinition/patient-birthTime", "valueInstant": "2001-05-06T14:35:45-05:00"}], "identifier": [{"use": "usual", "label": "MRN", "system": "urn:oid:1.2.36.146.595.217.0.1", "value": "12345", "period": {"start": "2001-05-06"}, "assigner": {"display": "Acme Healthcare"}}], "name": [{"use": "official", "family": ["Chalmers"], "given": ["Peter", "James"]}, {"use": "usual", "given": ["Jim"]}], "telecom": [{"use": "home"}, {"system": "phone", "value": "(03) 5555 6473", "use": "work"}], "gender": "male", "birthDate": "1974-12-25", "deceasedBoolean": false, "address": [{"use": "home", "line": ["534 Erewhon St"], "city": "PleasantVille", "state": "Vic", "postalCode": "3999"}], "contact": [{"relationship": [{"coding": [{"system": "http://hl7.org/fhir/patient-contact-relationship", "code": "partner"}]}], "name": {"family": ["du", "Marché"], "_family": [{"extension": [{"url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-qualifier", "valueCode": "VV"}]}, null], "given": ["Bénédicte"]}, "telecom": [{"system": "phone", "value": "+33 (237) 998327"}]}], "active": true}'::jsonb, 'id'::text, patients.content#>'{id}'))) FROM
-- -- (SELECT content FROM patient LIMIT 1000) patients;

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Delete Patient';
-- END
-- $$;

-- SELECT count(crud.delete('{}'::jsonb, 'Patient', patients.logical_id))
-- FROM (SELECT logical_id FROM patient LIMIT 1) patients;

-- SELECT count(crud.delete('{}'::jsonb, 'Patient', patients.logical_id))
-- FROM (SELECT logical_id FROM patient LIMIT 1000) patients;

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Search Patient by partial match without index and with many search candidates';
-- END
-- $$;

-- SELECT count(*) FROM fhir.search('Patient', 'name=John');

-- -- DO language plpgsql $$
-- -- BEGIN
-- --   RAISE NOTICE 'Search Patient for a nonexistent value without index';
-- -- END
-- -- $$;

-- -- SELECT count(*)
-- -- FROM fhir.search('Patient', 'name=nonexistentname');

-- -- DO language plpgsql $$
-- -- BEGIN
-- --   RAISE NOTICE 'Search Patient by partial match without index and with only one search candidate';
-- -- END
-- -- $$;

-- -- SELECT count(crud.create('{}'::jsonb,
-- --              jsonbext.merge(jsonbext.dissoc(patients.content, 'id'),
-- --                             json_build_object(
-- --                               'name', ARRAY[
-- --                                 json_build_object(
-- --                                  'given', ARRAY['foobarbaz']
-- --                                 )
-- --                               ]
-- --                             )::jsonb)))
-- -- FROM (SELECT content FROM patient LIMIT 1) patients;
-- -- SELECT count(*) FROM fhir.search('Patient', 'name=foobarbaz&_count=50000000');

-- select admin.admin_disk_usage_top(10);

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Indexing Patient name';
-- END
-- $$;

-- SELECT indexing.index_search_param('Patient','name');

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Search Patient for a nonexistent value using index';
-- END
-- $$;

-- SELECT count(*)
-- FROM fhir.search('Patient', 'name=nonexistentname');

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Search Patient by partial match using index and with many search candidates';
-- END
-- $$;

-- SELECT count(*)
-- FROM fhir.search('Patient', 'name=John&_count=50000000');

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'Search Patient by partial match using index and with only one search candidate';
-- END
-- $$;

-- SELECT count(crud.create('{}'::jsonb,
--              jsonbext.merge(jsonbext.dissoc(patients.content, 'id'),
--                             json_build_object(
--                               'name', ARRAY[
--                                 json_build_object(
--                                  'given', ARRAY['foobarbazwithindex']
--                                 )
--                               ]
--                             )::jsonb)))
-- FROM (SELECT content FROM patient LIMIT 1) patients;
-- SELECT count(*) FROM fhir.search('Patient',
--                                  'name=foobarbazwithindex&_count=50000000');

-- select admin.admin_disk_usage_top(10);

-- -- FIXME: Take to many time!
-- -- DO language plpgsql $$
-- -- BEGIN
-- --   RAISE NOTICE 'Indexing Patient birthDate';
-- -- END
-- -- $$;

-- -- SELECT indexing.index_search_param('Patient','birthdate');

-- -- FIXME: Take to many time!
-- -- DO language plpgsql $$
-- -- BEGIN
-- --   RAISE NOTICE 'Indexing Patient identifier';
-- -- END
-- -- $$;

-- -- SELECT indexing.index_search_param('Patient','identifier');

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'History for nonexistent patient';
-- END
-- $$;

-- SELECT crud.history('{}'::jsonb, 'Patient', 'nonexistentid');

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'History for one patient';
-- END
-- $$;

-- SELECT count(crud.create('{}'::jsonb,
--                          jsonbext.merge(patients.content,
--                                         '{"id": "foo-bar-id"}'::jsonb)))
-- FROM (SELECT content FROM patient LIMIT 1) patients;
-- SELECT crud.history('{}'::jsonb, 'Patient', 'foo-bar-id');

-- DO language plpgsql $$
-- BEGIN
--   RAISE NOTICE 'History for all patient';
-- END
-- $$;

-- SELECT count(crud.history('{}'::jsonb, 'Patient'));
