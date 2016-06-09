plv8 = require('../../../plpl/src/plv8')
assert = require('assert')

describe 'Issues', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  ###
  Issue #124
  Failed transaction response doesn't conform Bundle specification
  <https://github.com/fhirbase/fhirbase-plv8/issues/124>

  Hi!

  Issue connected with #119, but my case is related to errors during transaction:

  Trying to create resource of non-existing type:

  ```
  fhirbase=# SELECT fhir_transaction('{"resourceType":"Bundle","type":"transaction","entry":[{"resource":{"resourceType":"UnknownResource","active":true,"name":[{"use":"official","family":["Snow"],"given":["John"]}],"gender":"male","birthDate":"2001-01-01"},"request":{"method":"POST","url":"UnknownResource"}}]}');
  ```
  a response
  ```
  fhir_transaction | {"resourceType":"Bundle","type":"transaction-response","entry":[{"resourceType":"OperationOutcome","text":{"div":"<div>Storage for UnknownResource not exists</div>"},"issue":[{"severity":"error","code":"not-supported"}]}]}
  ```

  The response doesn't conform specification at: https://www.hl7.org/fhir/bundle-response.json.html

  Tested on v.1.3.0.15
  ###
  it "#124 Failed transaction response doesn't conform Bundle specification", ->
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
                    "resourceType":"UnknownResource",
                    "active":true,
                    "name":[
                      {"use":"official","family":["Snow"],"given":["John"]}
                    ],
                    "gender":"male",
                    "birthDate":"2001-01-01"
                  },
                  "request":{
                    "method":"POST","url":"UnknownResource"
                  }
                }
              ]
            }
          ');
        ''')[0].fhir_transaction
      )

    assert.equal(transaction.resourceType, 'OperationOutcome')
    assert.equal(
      transaction.issue[0].diagnostics,
      'Storage for UnknownResource not exists'
    )
