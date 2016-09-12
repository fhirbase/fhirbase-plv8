plv8 = require('../../plpl/src/plv8')
assert = require('assert')
helpers = require('../helpers')
match = helpers.match

json_call = (fn_name, params...) ->
  args = params.map((_, i)-> "$#{i+1}").join(',')
  res = plv8.execute("SELECT #{fn_name}(#{args})", params.map((x)-> JSON.stringify(x)))
  JSON.parse(res[0][fn_name])


describe 'Integration', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  describe 'Transaction', ->
    before ->
      plv8.execute('''SELECT fhir_create_storage('{"resourceType": "Patient"}');''')

    beforeEach ->
      plv8.execute('''SELECT fhir_truncate_storage('{"resourceType": "Patient"}');''')

    it 'seed data should be', ->

    it 'should processed in order (DELETE, POST, PUT, GET)', ->
      json_call(
        'fhir_create_resource',
        allowId: true,
        resource: {id: 'patient-to-delete-id', resourceType: 'Patient'}
      )

      json_call(
        'fhir_create_resource',
        allowId: true,
        resource: {
          id: 'patient-to-update-id',
          resourceType: 'Patient',
          name: [{given: ['Name to update']}]
        }
      )

      match(
        json_call(
          'fhir_search',
          resourceType: 'Patient',
          queryString: '_id=patient-to-delete-id'
        )
        total: 1
      )

      match(
        json_call(
          'fhir_search',
          resourceType: 'Patient',
          queryString: '_id=patient-to-update-id&name=Name to update'
        )
        total: 1
      )

      bundle =
        resourceType: 'Bundle'
        id: 'bundle-transaction-id'
        type: 'transaction'
        entry: [
          # GET (read) should processed last <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            request:
              method: 'GET'
              url: '/Patient?_id=patient-to-delete-id'
          }
          # GET (search) also should processed last <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            request:
              method: 'GET'
              url: '/Patient?name=Name to create'
          }
          # PUT (update) should processed after POST (create) <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            resource:
              resourceType: 'Patient'
              active: true
              name: [{family: ['Name to update updated']}]
            request:
              method: 'PUT'
              url: '/Patient/patient-to-update-id'
          }
          # POST (create) should processed after DELETE <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            resource:
              resourceType: 'Patient'
              name: [{family: ['Name to create']}]
            request:
              method: 'POST'
              url: '/Patient'
          }
          # DELETE should processed first <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            request:
               method: 'DELETE'
               url: '/Patient/patient-to-delete-id'
          }
        ]


      match(
        json_call('fhir_transaction', bundle),
        resourceType: 'Bundle'
        type: 'transaction-response'
        entry: [
          {
            resource:
              id: 'patient-to-delete-id'
              resourceType: 'Patient' 
              meta:
                extension: [{url: 'fhir-request-method', valueString: 'DELETE'}]
          }
          {
            resource:
              resourceType: 'Patient' 
              name: [{family: ['Name to create']}]
              meta:
                extension: [{url: 'fhir-request-method', valueString: 'POST'}]
          }
          {
            resource:
              id: 'patient-to-update-id'
              resourceType: 'Patient' 
              name: [{family: ['Name to update updated']}]
              meta:
                extension: [{url: 'fhir-request-method', valueString: 'PUT'}]
          }
          {
            resource:
              resourceType: 'Bundle' 
              type: 'searchset'
              link: [{url: '/Patient?_id=patient-to-delete-id&_page=0'}]
              total: 0
          }
          {
            resource:
              resourceType: 'Bundle' 
              type: 'searchset'
              total: 1
              entry: [{resource: {resourceType: 'Patient', name: [{family: ['Name to create']}]}}]
          }
        ]
      )

    it "should create with ID and respects ID's references", ->

      json_call('fhir_create_storage', resourceType: 'Practitioner')

      bundle =
        resourceType: 'Bundle'
        id: 'bundle-transaction-id'
        type: 'transaction'
        entry: [
          {
            resource:
              resourceType: 'Practitioner'
            request:
              method: 'PUT'
              url: '/Practitioner/created-and-referenced-id'
          }
          {
            resource:
              resourceType: 'Patient'
              generalPractitioner: [
                {reference: '/Practitioner/created-and-referenced-id'}
              ]
            request:
              method: 'PUT'
              url: '/Patient/patient-to-update-id'
          }
          {
            request:
              method: 'GET'
              url: '/Patient?_id=patient-to-update-id&_include=general-practitioner'
          }
        ]


      match(
        json_call('fhir_transaction', bundle)
        entry: [
          {},
          {},
          {
            resource:
              total: 1
              resourceType: 'Bundle'
              type: 'searchset'
              entry: [
                {},
                resource:
                  resourceType: 'Practitioner'
                  id: 'created-and-referenced-id'
              ]
          }
       ]
      )

    it 'narus transaction', ->

      json_call('fhir_create_storage', {resourceType: "Practitioner"})
      json_call(
        'fhir_create_resource',
        allowId: true,
        resource: {id: "patient-id", resourceType: "Patient"}
      )

      bundle = 
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [
          {
            "resource": {
              "resourceType": "Practitioner"
            },
            "request": {
              "method": "PUT",
              "url": "/Practitioner/practitioner-id"
            }
          },
          {
            "resource": {
              "resourceType": "Patient",
              "generalPractitioner": [
                {
                  "reference": "/Practitioner/practitioner-id"
                }
              ]
            },
            "request": {
              "method": "PUT",
              "url": "/Patient/patient-id"
            }
          },
          {
            "request": {
              "method": "GET",
              "url": "/Patient?_id=patient-id&_include=general-practitioner"
            }
          }
        ]

      match(
        json_call('fhir_transaction', bundle)
        entry: [
          {},
          {},
          {
            resource:
              total: 1
              resourceType: 'Bundle'
              type: 'searchset'
              entry: [
                {},
                resource:
                  resourceType: 'Practitioner'
                  id: 'practitioner-id'
              ]
          }
       ]
      )

    it 'should rollback (#112)', ->
      json_call(
        'fhir_create_resource',
        allowId: true,
        resource:
          id: "id1",
          resourceType: "Patient",
          name: [{"given": ["Patient 1"]}]
      )

      bundle =
        type: "transaction",
        id: "bundle-transaction",
        resourceType: "Bundle",
        entry: [
          {
            request:
              url: '/Patient/id1',
              method: "DELETE"
          },
          {
            request:
              url: '/Patient/id2',
              method: "DELETE"
          }
        ]

      match(
        json_call('fhir_transaction', bundle),
        resourceType: 'OperationOutcome'
        issue: [{severity: 'error', code: 'not-found', diagnostics: 'Resource Id "id2" does not exist'}]
      )

      match(
        json_call('fhir_read_resource', id: 'id1', resourceType: "Patient"),
        resourceType: 'Patient'
        id: 'id1'
      )

    it 'should report error message', ->
      bundle =
        type: "transaction",
        id: "bundle-transaction",
        resourceType: "Bundle",
        entry: [
          {
            request:
              url: '/Patient/id1',
              method: "POST"
          }
        ]

      match(
        json_call('fhir_transaction', bundle),
        resourceType: 'OperationOutcome'
        issue: [
          {
            severity: 'error',
            code: '422',
            diagnostics: 'Invalid operation POST /Patient/id1'
          }
        ]
      )
