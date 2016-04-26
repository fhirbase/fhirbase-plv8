fhir_benchmark = (plv8, query)->
  create_patients = (limit)->
    """
    SELECT count(
             fhir_create_resource(
               fhir_benchmark_dissoc(patients.resource::json, 'id')
             )
           )
           FROM (SELECT resource FROM patient LIMIT #{limit}) patients;
    """
  read_patients = (limit)->
    """
    SELECT count(
             fhir_read_resource(
               fhir_benchmark_dissoc(patients.resource::json, 'versionId')
             )
           )
           FROM (SELECT resource FROM patient LIMIT #{limit}) patients;
    """

  create_temporary_patients = (limit)->
    """
    DROP TABLE IF EXISTS temp_patient_data;
    CREATE TABLE temp_patient_data (data jsonb);
    INSERT INTO temp_patient_data (data)
           SELECT fhir_benchmark_merge(
                    resource::json,
                    '{"multipleBirthBoolean": true}'::json
                  )::jsonb
           FROM patient LIMIT #{limit};
    """

  update_patients = (limit)->
    """
    SELECT count(
             fhir_update_resource(
               ('{"resource":' || temp_patients.data || '}')::json
             )
           )
           FROM
           (SELECT data FROM temp_patient_data LIMIT #{limit}) temp_patients;
    """

  delete_patients = (limit)->
    """
    SELECT count(
             fhir_delete_resource(
               (
                 '{"resourceType": "Patient", "id": "' || patients.id || '"}'
               )::json
             )
           )
           FROM (SELECT id FROM patient LIMIT #{limit}) patients;
    """

  fhir_search = (query)->
    """
    SELECT count(*) FROM fhir_search('#{query}'::json);
    """
  performance_search = ()->
    """
    SELECT count(fhir_create_resource(
      fhir_benchmark_merge(
        fhir_benchmark_dissoc(patients.resource::json, 'id'),
        json_build_object('name', ARRAY[json_build_object('given', ARRAY['foobarbaz'])])::json)))
    FROM (SELECT resource FROM patient LIMIT 1) patients;
    SELECT count(*)
    FROM fhir_search('{"resourceType": "Patient", "queryString": "name=foobarbaz&_count=50000000"}');
    """

  performance_search_param = (resourceType, name)->
    """
    SELECT fhir_unindex_parameter('{"resourceType": "#{resourceType}", "name": "#{name}"}');
    SELECT fhir_index_parameter('{"resourceType": "#{resourceType}", "name": "#{name}"}');
    """

  disk_usage_top = (limit)->
    """
    SELECT count(*) FROM fhirbase_disk_usage_top('{"limit": #{limit}}'::json);
    """

  benchmarks = [
    {
      description: 'fhir_create_resource called just one time'
      statement: create_patients(1)
    },
    {
      description: 'fhir_create_resource called 1000 times in batch'
      statement: create_patients(1000)
    },
    {
      description: 'fhir_read_resource called just one time'
      statement: read_patients(1)
    },
    {
      description: 'fhir_read_resource called 1000 times in batch'
      statement: read_patients(1000)
    },
    {
      description: "disk usage right after generation of seed data"
      statement: disk_usage_top(10)
    },
    {
      description: "Updating single patient with fhir_update_resource",
      beforeStatement: create_temporary_patients(1000),
      statement: update_patients(1)
    },
    {

      description: "fhir_delete_resource called one time",
      statement: delete_patients(1)
    },
    {
      description: "fhir_delete_resource called 1000 times in batch",
      statement: delete_patients(1000)
    },
    {
      description: "searching for non-existent name without index"
      statement: fhir_search('{"resourceType": "Patient", "queryString": "name=nonexistentname"}')
    },
    {
      description: "building Patient.name index"
      statement: performance_search_param('Patient','name')
    },
    {
      description: "building Patient.gender index"
      statement: performance_search_param('Patient','gender')
    },
    {
      description: "building Patient.address index"
      statement: performance_search_param('Patient','address')
    },
    {
      description: "building Patient.telecom index"
      statement: performance_search_param('Patient','telecom')
    },
    {
      description: "building Practitioner.name index"
      statement: performance_search_param('Practitioner','name')
    },
    {
      description: "building Organization.name index"
      statement: performance_search_param('Organization','name')
    },
    {
      description: "building Encounter.status index"
      statement: performance_search_param('Encounter','status')
    },
    {
      description: "building Encounter.patient index"
      statement: performance_search_param('Encounter','patient')
    },
    {
      description: "building Encounter.participant index"
      statement: performance_search_param('Encounter','participant')
    },
    {
      description: "building Encounter.practitioner index"
      statement: performance_search_param('Encounter','practitioner')
    },
    {
      description: "building Patient.organization index"
      statement: performance_search_param('Patient','organization')
    },
    {
      description: "building Patient.birthdate index"
      statement: performance_search_param('Patient','birthdate')
    },
    {
      description: "running VACUUM ANALYZE on patient table",
      statement: "VACUUM ANALYZE patient",
      skip: true
    },
    {
      description: "running VACUUM ANALYZE on encounter table",
      statement: "VACUUM ANALYZE encounter",
      skip: true
    },
    {
      description: "running VACUUM ANALYZE on organization table",
      statement: "VACUUM ANALYZE organization",
      skip: true
    },
    {
      description: "running VACUUM ANALYZE on practitioner table",
      statement: "VACUUM ANALYZE practitioner",
      skip: true
    },
    {
      description: "searching for patient with unique name"
      statement: performance_search()
    },
    {
      description: "searching for all Johns in database"
      statement: fhir_search('{"resourceType": "Patient", "queryString": "name=John&_count=50000000"}')
    },
    {
      description: "searching Patient with name=John&gender=female&_count=100 (should have no matches at all)"
      statement: fhir_search('{"resourceType": "Patient", "querySTring": "name=John&gender=female&_count=100"}')
    },
    {
      description: "searching Patient with name=John&gender=male&_count=100"
      statement: fhir_search('{"resourceType": "Patient", "queryString": "name=John&gender=male&_count=100"}')
    },
    {
      description: "searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100"
      statement: fhir_search('{"resourceType": "Patient", "queryString": "name=John&gender=male&active=true&address=YALUMBA&_count=100"}')
    },
    {
      description: "searching Patient with name=John&gender=male&_count=100&_sort=name",
      statement: fhir_search('{"resourceType": "Patient", "queryString": "name=John&gender=male&_count=100&_sort=name"}')
    },
    {
      description: "searching Patient with name=John&gender=male&_count=100&_sort=active"
      statement: fhir_search('{"resourceType": "Patient", "queryString": "name=John&gender=male&_count=100&_sort=active"}')
    },
    {
      description: "searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex"
      #statement: fhir_search('{"resourceType": "Encounter", "queryString": "patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex"}')
      statement: fhir_search('{"resourceType": "Encounter", "queryString": "patient:Patient.name=John&_count=100&practitioner:Practitioner.name=Alex"}')
    },
    {
      description: "searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis"
      statement: fhir_search('{"resourceType": "Encounter", "queryString": "patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis"}')
    },
    {
      description: "Wait 5 seconds"
      statement: "SELECT pg_sleep(5)"
      skip: true
    }
  ]

  benchmarks = (b for b in benchmarks when not b.skip).map (benchmark)->
    if benchmark.beforeStatement
      plv8.execute(benchmark.beforeStatement)

    t1 = new Date()
    plv8.execute(benchmark.statement)
    t2 = new Date()
    {
      description: benchmark.description
      time: t2 - t1
    }

  {operations: benchmarks}

exports.fhir_benchmark = fhir_benchmark
exports.fhir_benchmark.plv8_signature = ['json', 'json']

fhir_benchmark_dissoc = (plv8, object, property)->
  delete object[property]
  object

exports.fhir_benchmark_dissoc = fhir_benchmark_dissoc
exports.fhir_benchmark_dissoc.plv8_signature = {
  arguments: ['json', 'text']
  returns: 'json'
  immutable: true
}

fhir_benchmark_merge = (plv8, object1, object2)->
  object3 = {}

  for key, value of object1
    object3[key] = value

  for key, value of object2
    object3[key] = value

  object3

exports.fhir_benchmark_merge = fhir_benchmark_merge
exports.fhir_benchmark_merge.plv8_signature = {
  arguments: ['json', 'json']
  returns: 'json'
  immutable: true
}
