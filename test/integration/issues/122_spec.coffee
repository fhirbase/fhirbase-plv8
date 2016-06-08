plv8 = require('../../../plpl/src/plv8')
assert = require('assert')

describe 'Issues', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it '#122', ->
    plv8.execute('''
      SELECT fhir_create_storage('{"resourceType": "Patient"}');
    ''')
    plv8.execute('''
      SELECT fhir_truncate_storage('{"resourceType": "Patient"}');
    ''')

    plv8.execute('''
      SELECT fhir_create_resource('
        {"allowId": true,
         "resource": {
           "id": "id1",
           "resourceType": "Patient",
           "name": [{"given": ["Jim"]}],
           "identifier": [
             {"use": "official", "value": "0987", "system": "test"}
           ]
         }
       }
      ');
    ''')

    transaction =
      JSON.parse(
        plv8.execute('''
          SELECT fhir_transaction('
            {
              "resourceType":"Bundle",
              "id":"bundle-transaction",
              "type":"transaction",
              "entry":[
                {
                  "resource":{
                    "resourceType":"Patient",
                    "name":[
                      {
                        "use":"official",
                        "family":["Chalmers"],
                        "given":["Peter","James"]
                      }
                    ],
                    "gender":"male",
                    "birthDate":"1974-12-25",
                    "active":true
                  },
                  "request":{"method":"POST","url":"/Patient"}
                }, {
                  "resource":{
                    "name":[
                      {
                        "use":"official",
                        "family":["Martin"],
                        "given":["Bob"]
                      }
                    ],
                    "gender":"male",
                    "birthDate":"1955-05-05",
                    "active":true
                  },
                  "request":{"method":"PUT","url":"/Patient/1234"}
                }, {
                  "request":{"method":"DELETE","url":"/Patient/id1"}
                }
              ]
            }
          ');
        ''')[0].fhir_transaction
      )

    assert.equal(transaction.resourceType, 'OperationOutcome')
    assert.equal(
      transaction.issue[0].diagnostics,
      'Could not update resource without resourceType'
    )

    patient =
      JSON.parse(
        plv8.execute('''
          SELECT fhir_read_resource('
            {"id": "id1", "resourceType": "Patient"}
          ');
        ''')[0].fhir_read_resource
      )

    assert.equal(patient.resourceType, 'Patient')
    assert.equal(patient.id, 'id1')
    assert.equal(patient.name[0].given, 'Jim')

    search =
      JSON.parse(
        plv8.execute('''
          SELECT fhir_search('
            {"resourceType": "Patient", "queryString": "name=Peter,James,Chalmers"}
          ');
        ''')[0].fhir_search
      )

    assert.equal(search.total, 0)
