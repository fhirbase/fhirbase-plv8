plv8 = require('../../../plpl/src/plv8')
assert = require('assert')

describe 'Issues', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  ###
  Issue #123
  Create by PUT inside transaction doesn't work
  <https://github.com/fhirbase/fhirbase-plv8/issues/123>

  Hi!

  Issue found on v1.3.0.15. When inside transaction resource with given id is to be created by PUT, fhirbase raises error and resource isn't created.

  ```
  fhirbase=# SELECT fhir_drop_storage('{"resourceType": "Patient"}');
  -[ RECORD 1 ]-----+------------------------------------------------------
  fhir_drop_storage | {"status":"ok","message":"Table patient was dropped"}

  fhirbase=# SELECT fhir_create_storage('{"resourceType": "Patient"}');
  -[ RECORD 1 ]-------+------------------------------------------------------
  fhir_create_storage | {"status":"ok","message":"Table patient was created"}

  fhirbase=# SELECT resource ->> 'name' from patient;
  (No rows)
  fhirbase=# SELECT resource FROM patient;
  (No rows)
  fhirbase=# SELECT fhir_transaction('{"resourceType":"Bundle","type":"transaction","entry":[{"resource":{"resourceType":"Patient","id":"bbb-ccc-ddd-123","active":true,"name":[{"use":"official","family":["Snow"],"given":["John"]}],"gender":"male","birthDate":"2001-01-01"},"request":{"method":"PUT","url":"Patient/bbb-ccc-ddd-123"}}]}');
  -[ RECORD 1 ]----+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  fhir_transaction | {"resourceType":"OperationOutcome","message":"There were incorrect requests within transaction. [{\"type\":\"error\",\"message\":\"Cannot determine action for request PUT Patient/bbb-ccc-ddd-123\"}]"}

  fhirbase=# SELECT resource FROM patient;
  (No rows)
  ```
  ###
  it "#123 Create by PUT inside transaction doesn't work", ->
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
