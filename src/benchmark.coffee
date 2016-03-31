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
  fhir_search = (query)->
    """
    SELECT count(*) FROM fhir_search('#{query}'::json);
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
      statement: "SELECT admin.admin_disk_usage_top(10)"
      skip: true
    },
    {
      description: "fhir.create called just one time"
      statement: "SELECT performance.create_patients(1)"
      skip: true
    },
    {
      description: "fhir.create called 1000 times in batch"
      statement: "SELECT performance.create_patients(1000)"
      skip: true
    },
    {
      description: "fhir.read called just one time"
      statement: "SELECT performance.read_patients(1)"
      skip: true
    },
    {
      description: "fhir.read called 1000 times in batch",
      statement: "SELECT performance.read_patients(1000)",
      skip: true
    },
    {
      description: "Updating single patient with fhir.update()",
      statement: "SELECT performance.create_temporary_patients(1000);\nSELECT performance.update_patients(1)",
      skip: true
    },
    {
      description: "fhir.delete called one time",
      statement: "SELECT performance.delete_patients(1)",
      skip: true
    },
    {
      description: "fhir.delete called 1000 times in batch",
      statement: "SELECT performance.delete_patients(1000)",
      skip: true
    },
    {
      description: "searching for non-existent name without index",
      statement: "SELECT count(*) FROM fhir.search('Patient', 'name=nonexistentname')",
      skip: true
    },
    {
      description: "building Patient.name index",
      statement: "SELECT performance.index_search_param('Patient','name')",
      skip: true
    },
    {
      description: "building Patient.gender index",
      statement: "SELECT performance.index_search_param('Patient','gender')",
      skip: true
    },
    {
      description: "building Patient.address index",
      statement: "SELECT performance.index_search_param('Patient','address')",
      skip: true
    },
    {
      description: "building Patient.telecom index",
      statement: "SELECT performance.index_search_param('Patient','telecom')",
      skip: true
    },
    {
      description: "building Participant.name index",
      statement: "SELECT performance.index_search_param('Participant','name')",
      skip: true
    },
    {
      description: "building Organization.name index",
      statement: "SELECT performance.index_search_param('Organization','name')",
      skip: true
    },
    {
      description: "building Encounter.status index",
      statement: "SELECT performance.index_search_param('Encounter','status')",
      skip: true
    },
    {
      description: "building Encounter.patient index",
      statement: "SELECT performance.index_search_param('Encounter','patient')",
      skip: true
    },
    {
      description: "building Encounter.participant index",
      statement: "SELECT performance.index_search_param('Encounter','participant')",
      skip: true
    },
    {
      description: "building Encounter.practitioner index",
      statement: "SELECT performance.index_search_param('Encounter','practitioner')",
      skip: true
    },
    {
      description: "building Patient.organization index",
      statement: "SELECT performance.index_search_param('Patient','organization')",
      skip: true
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
      description: "searching for patient with unique name",
      statement: "SELECT performance.search_patient_with_only_one_search_candidate()",
      skip: true
    },
    {
      description: "searching for all Johns in database",
      statement: "SELECT count(*) FROM fhir.search('Patient', 'name=John&_count=50000000')",
      skip: true
    },
    {
      description: "searching Patient with name=John&gender=female&_count=100 (should have no matches at all)",
      statement: "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=female&_count=100')",
      skip: true
    },
    {
      description: "searching Patient with name=John&gender=male&_count=100",
      statement: "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&_count=100')",
      skip: true
    },
    {
      description: "searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100",
      statement: "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&active=true&address=YALUMBA&_count=100')",
      skip: true
    },
    {
      description: "searching Patient with name=John&gender=male&_count=100&_sort=name",
      statement: "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&_count=100&_sort=name')",
      skip: true
    },
    {
      description: "searching Patient with name=John&gender=male&_count=100&_sort=active",
      statement: "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&_count=100&_sort=active')",
      skip: true
    },
    {
      description: "searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex",
      statement: "SELECT count(*) FROM fhir.search('Encounter', 'patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex')",
      skip: true
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
