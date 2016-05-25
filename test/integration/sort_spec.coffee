plv8 = require('../../plpl/src/plv8')
assert = require('assert')

describe 'Integration', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  describe 'Sorting', ->
    before ->
      plv8.execute('''
        SELECT fhir_create_storage('{"resourceType": "Patient"}');
      ''')

    beforeEach ->
      plv8.execute('''
        SELECT fhir_truncate_storage('{"resourceType": "Patient"}');
      ''')

    it 'by date', ->
      plv8.execute('''
        SELECT fhir_create_resource('
          {"resource": {"resourceType": "Patient", "birthDate": "1970-01-01"}}
        ');
        SELECT fhir_create_resource('
          {"resource": {"resourceType": "Patient", "birthDate": "1970-01-02"}}
        ');
        SELECT fhir_create_resource('
          {"resource": {"resourceType": "Patient", "birthDate": "1970-01-03"}}
        ');
      ''')

      patientsAsc =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_search('
              {"resourceType": "Patient", "queryString": "_sort=birthdate"}
            ');
          ''')[0].fhir_search
        ).entry

      patientsDesc =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_search('
              {"resourceType": "Patient", "queryString": "_sort:desc=birthdate"}
            ');
          ''')[0].fhir_search
        ).entry

      assert.deepEqual(
        patientsAsc.map((patient)-> patient.resource.birthDate),
        ['1970-01-01', '1970-01-02', '1970-01-03']
      )
      assert.deepEqual(
        patientsDesc.map((patient)-> patient.resource.birthDate),
        ['1970-01-03', '1970-01-02', '1970-01-01']
      )
