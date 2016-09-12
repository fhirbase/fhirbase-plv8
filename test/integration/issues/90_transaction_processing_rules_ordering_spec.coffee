plv8 = require('../../../plpl/src/plv8')
assert = require('assert')

helpers = require('../../helpers')
match = helpers.match

###
Issue #90
Transaction - processing rules - ordering
<https://github.com/fhirbase/fhirbase-plv8/issues/90>
###
describe 'Issues', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  describe '#90 Transaction processing ordering', ->
    ###
    Got some issues with ordering operations
    <https://github.com/fhirbase/fhirbase-plv8/issues/90#issuecomment-225587083>

    Transaction returns OperationOutcome issue with code 'not-found'.
    This is expected behavior because transaction should processed
    in order (DELETE, POST, PUT, GET)
    <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
    ###
    it 'should return OperationOutcome even read goes before delete', ->
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
              "id": "patient-to-delete-id"
            }
          }
        ');
      ''')
      plv8.execute('''
        SELECT fhir_create_resource('
          {
            "allowId": true,
            "resource": {
              "resourceType": "Patient",
              "name": [{"given": ["NameToBeUpdated"]}],
              "id": "patient-to-update-id"
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
                  {
                    "request":{"method":"GET","url":"/Patient/patient-to-delete-id"}
                  },
                  {
                    "request":{"method":"GET","url":"/Patient?name=NameCreated"}
                  },
                  {
                    "request":{"method":"PUT","url":"/Patient/patient-to-update-id"},
                    "resource":{"resourceType":"Patient","active":true,"name":[{"family":["NameUpdated"]}]}
                  },
                  {
                    "request":{"method":"POST","url":"/Patient"},
                    "resource":{"resourceType":"Patient","name":[{"family":["NameCreated"]}]}
                  },
                  {
                    "request":{"method":"DELETE","url":"/Patient/patient-to-delete-id"}
                  }
                ]
              }
            ');
          ''')[0].fhir_transaction
        )

      match(
        transaction,
        resourceType: 'OperationOutcome'
        issue: [
          {
            severity: 'error',
            code: 'not-found',
            diagnostics: 'Resource Id "patient-to-delete-id" with versionId "undefined" has been deleted'
          }
        ]
      )
