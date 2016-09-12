plv8 = require('../../../plpl/src/plv8')
assert = require('assert')

describe 'Issues', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  ###
  Issue #122
  Transactions are not rolled back on failure
  <https://github.com/fhirbase/fhirbase-plv8/issues/122>

  Hi!

  I retested the issue #112 on v1.3.0.15 and the problem still exists.

  ```
  SELECT fhir_drop_storage('{"resourceType": "Patient"}');
  SELECT fhir_create_storage('{"resourceType": "Patient"}');

  SELECT fhir_create_resource('{"allowId": true, "resource": {"id": "id1", "resourceType": "Patient","name": [{"given": ["Jim"]}], "identifier": [{"use": "official", "value": "0987", "system": "test"}]}}');
  ```

  Check what are patient names at this moment

  ```
  SELECT resource ->> 'name' from patient;

  -[ RECORD 1 ]------------------
  ?column? | [{"given": ["Jim"]}]
  ```

  now the transaction:

  ```
  SELECT fhir_transaction('{"resourceType":"Bundle","id":"bundle-transaction","type":"transaction","entry":[{"resource":{"resourceType":"Patient","name":[{"use":"official","family":["Chalmers"],"given":["Peter","James"]}],"gender":"male","birthDate":"1974-12-25","active":true},"request":{"method":"POST","url":"/Patient"}},{"resource":{"name":[{"use":"official","family":["Martin"],"given":["Bob"]}],"gender":"male","birthDate":"1955-05-05","active":true},"request":{"method":"PUT","url":"/Patient/1234"}},{"request":{"method":"DELETE","url":"/Patient/id1"}}]}');
  ```

  and its response with a failure for an update:

  ```
  fhir_transaction | {"resourceType":"Bundle","type":"transaction-response","entry":[{"resourceType":"Patient","name":[{"use":"official","family":["Chalmers"],"given":["Peter","James"]}],"gender":"male","birthDate":"1974-12-25","active":true,"id":"0cd5434d-e2a5-4019-a572-a05ee54d0da4","meta":{"versionId":"419e341f-6e8b-4f4a-b2f6-cb03d80868ee","lastUpdated":"2016-06-07T15:39:54.715Z","extension":[{"url":"fhir-request-method","valueString":"POST"},{"url":"fhir-request-uri","valueUri":"Patient"}]}},{"resourceType":"OperationOutcome","issue":[{"severity":"error","code":"400","diagnostics":"Could not update resource without resourceType"}]},{"id":"id1","meta":{"extension":[{"url":"fhir-request-method","valueString":"DELETE"},{"url":"fhir-request-uri","valueUri":"Patient"}],"versionId":"9388401e-d04a-43a1-bd7e-5c3237f08f1a","lastUpdated":"2016-06-07T15:39:54.720Z"},"name":[{"given":["Jim"]}],"identifier":[{"use":"official","value":"0987","system":"test"}],"resourceType":"Patient"}]}
  ```

  and again checks:

  1) We don't have Patient with the name  "Jim", he was deleted in a transaction

  ```
  SELECT fhir_read_resource('{"resourceType": "Patient", "id": "id1"}');
  -[ RECORD 1 ]------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  fhir_read_resource | {"resourceType":"OperationOutcome","issue":[{"severity":"error","code":"not-found","details":{"coding":[{"code":"MSG_DELETED_ID","display":"The resource \"id1\" has been deleted"}]},"diagnostics":"Resource Id \"id1\" with versionId \"undefined\" has been deleted"}]}
  ```

  2) but we have this one added in a transaction
  ```
  SELECT resource ->> 'name' from patient;                                                                                                                                                                                         -[ RECORD 1 ]------------------------------------------------------------------------
  ?column? | [{"use": "official", "given": ["Peter", "James"], "family": ["Chalmers"]}]
  ```
  ###
  it '#122 Transactions are not rolled back on failure', ->
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
