plv8 = require('../../../plpl/src/plv8')
assert = require('assert')

describe 'Issues', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it '#123', ->
    plv8.execute('''
      SELECT fhir_create_storage('{"resourceType": "Patient"}');
    ''')
    plv8.execute('''
      SELECT fhir_truncate_storage('{"resourceType": "Patient"}');
    ''')

    transaction =
      JSON.parse(
        plv8.execute('''
          SELECT fhir_transaction('
            {
              "resourceType":"Bundle",
              "type":"transaction",
              "entry":[
                {
                  "resource":{
                    "resourceType":"Patient",
                    "id":"bbb-ccc-ddd-123",
                    "active":true,
                    "name":[
                      {"use":"official","family":["Snow"],"given":["John"]}
                    ],
                    "gender":"male",
                    "birthDate":"2001-01-01"
                  },
                  "request":{
                    "method":"PUT","url":"Patient/bbb-ccc-ddd-123"
                  }
                }
              ]
            }
          ');
        ''')[0].fhir_transaction
      )

    assert.equal(transaction.type, 'transaction-response')
    assert.equal(transaction.entry[0].resource.resourceType, 'Patient')
    assert.equal(transaction.entry[0].resource.id, 'bbb-ccc-ddd-123')
