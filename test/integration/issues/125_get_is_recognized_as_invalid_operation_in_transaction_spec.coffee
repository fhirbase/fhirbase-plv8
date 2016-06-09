plv8 = require('../../../plpl/src/plv8')
assert = require('assert')

describe 'Issues', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  ###
  Issue #125
  GET is recognized as invalid operation in transaction
  <https://github.com/fhirbase/fhirbase-plv8/issues/125>

    Hi!

  Tested on v1.3.0.21.

  ```
  SELECT fhir_truncate_storage('{"resourceType": "Patient"}');

  SELECT fhir_create_resource('{"allowId": true, "resource": {"resourceType": "Patient","name": [{"given": ["Tim"]}], "id": "2345"}}');

  select fhir_transaction('{"resourceType":"Bundle","type":"transaction","entry":[{"request":{"method":"GET","url":"Patient/2345"}}]}');
  ```
  the output of the transaction is:
    ```
  {"resourceType":"OperationOutcome","issue":[{"severity":"error","code":"422","diagnostics":"Invalid operation GET Patient/2345"}]}
  ```
  ###
  it '#125 one more transaction respects urls without leading slash', ->
    plv8.execute('''
      SELECT fhir_create_storage('{"resourceType": "Patient"}');
    ''')
    plv8.execute('''
      SELECT fhir_truncate_storage('{"resourceType": "Patient"}');
    ''')
    plv8.execute('''
      SELECT fhir_create_resource('
        {
          "allowId": true,
          "resource": {
            "resourceType": "Patient",
            "name": [{"given": ["Tim"]}],
            "id": "2345"
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
              "type":"transaction",
              "entry":[
                {"request":{"method":"GET","url":"Patient/2345"}}
              ]
            }
          ');
        ''')[0].fhir_transaction
      )

    assert.equal(transaction.type, 'transaction-response')
    assert.equal(transaction.entry[0].resource.resourceType, 'Patient')
    assert.equal(transaction.entry[0].resource.id, '2345')
