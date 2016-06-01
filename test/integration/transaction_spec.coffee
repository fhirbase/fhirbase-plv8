plv8 = require('../../plpl/src/plv8')
assert = require('assert')

describe 'Integration', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  describe 'Transaction', ->
    before ->
      plv8.execute('''SELECT fhir_create_storage('{"resourceType": "Patient"}');''')

    beforeEach ->
      plv8.execute('''SELECT fhir_truncate_storage('{"resourceType": "Patient"}');''')

      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(
          allowId: true,
          resource: {id: 'patient-to-delete-id', resourceType: 'Patient'}
        )]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(
          allowId: true,
          resource: {
            id: 'patient-to-update-id',
            resourceType: 'Patient',
            name: [{given: ['Name to update']}]
          }
        )]
      )

    it 'seed data should be', ->
      assert.equal(
        JSON.parse(
          plv8.execute(
            'SELECT fhir_search($1)',
            [JSON.stringify(
              resourceType: 'Patient',
              queryString: '_id=patient-to-delete-id'
            )]
          )[0].fhir_search
        ).total,
        1
      )
      assert.equal(
        JSON.parse(
          plv8.execute(
            'SELECT fhir_search($1)',
            [JSON.stringify(
              resourceType: 'Patient',
              queryString: '_id=patient-to-update-id&name=Name to update'
            )]
          )[0].fhir_search
        ).total,
        1
      )

    it 'should processed in order (DELETE, POST, PUT, GET)', ->
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

      transaction =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_transaction($1)',
            [JSON.stringify(bundle)]
          )[0].fhir_transaction
        )

      assert.equal(transaction.resourceType, 'Bundle')
      assert.equal(transaction.type, 'transaction-response')

      assert.equal(transaction.entry[0].resourceType, 'Patient')
      assert.equal(transaction.entry[0].meta.extension[0].url, 'fhir-request-method')
      assert.equal(transaction.entry[0].meta.extension[0].valueString, 'DELETE')
      assert.equal(transaction.entry[0].id, 'patient-to-delete-id')

      assert.equal(transaction.entry[1].resourceType, 'Patient')
      assert.equal(transaction.entry[1].meta.extension[0].url, 'fhir-request-method')
      assert.equal(transaction.entry[1].meta.extension[0].valueString, 'POST')
      assert.equal(transaction.entry[1].name[0].family[0], 'Name to create')

      assert.equal(transaction.entry[2].resourceType, 'Patient')
      assert.equal(transaction.entry[2].meta.extension[0].url, 'fhir-request-method')
      assert.equal(transaction.entry[2].meta.extension[0].valueString, 'PUT')
      assert.equal(transaction.entry[2].id, 'patient-to-update-id')
      assert.equal(transaction.entry[2].name[0].family[0], 'Name to update updated')

      assert.equal(transaction.entry[3].resourceType, 'Bundle')
      assert.equal(transaction.entry[3].type, 'searchset')
      assert.equal(transaction.entry[3].link[0].url, '/Patient?_id=patient-to-delete-id&_page=0')
      assert.equal(transaction.entry[3].total, 0)

      assert.equal(transaction.entry[4].resourceType, 'Bundle')
      assert.equal(transaction.entry[4].type, 'searchset')
      assert.equal(transaction.entry[4].total, 1)
      assert.equal(transaction.entry[4].entry[0].resource.resourceType, 'Patient')
      assert.equal(transaction.entry[4].entry[0].resource.name[0].family[0], 'Name to create')

    it "should create with ID and respects ID's references", ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Practitioner')]
      )

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
              careProvider: [
                {reference: '/Practitioner/created-and-referenced-id'}
              ]
            request:
              method: 'PUT'
              url: '/Patient/patient-to-update-id'
          }
          {
            request:
              method: 'GET'
              url: '/Patient?_id=patient-to-update-id&_include=careprovider'
          }
        ]

      transaction =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_transaction($1)',
            [JSON.stringify(bundle)]
          )[0].fhir_transaction
        )

      assert.equal(transaction.entry[2].total, 1)
      assert.equal(
        transaction.entry[2].entry.filter((resource)->
          resource.resource.resourceType == 'Practitioner'
        )[0].resource.id,
        'created-and-referenced-id'
      )

    it 'narus transaction', ->
      plv8.execute('''
        SELECT fhir_create_storage('{"resourceType": "Practitioner"}');
      ''')

      plv8.execute('''
        SELECT fhir_create_resource('
          {
            "allowId": true,
            "resource": {"id": "patient-id", "resourceType": "Patient"}
          }
        ');
      ''')

      transaction =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_transaction('
              {
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
                      "careProvider": [
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
                      "url": "/Patient?_id=patient-id&_include=careprovider"
                    }
                  }
                ]
              }
            ');
          ''')[0].fhir_transaction
        )

      assert.equal(transaction.entry[2].total, 1)
      assert.equal(
        transaction.entry[2].entry.filter((resource)->
          resource.resource.resourceType == 'Practitioner'
        )[0].resource.id,
        'practitioner-id'
      )

    it 'should rollback (#112)', ->
      plv8.execute('''
        SELECT fhir_create_resource('
          {
            "allowId": true,
            "resource": {
              "id": "id1",
              "resourceType": "Patient",
              "name": [{"given": ["Patient 1"]}]
            }
          }
        ');
      ''')

      transaction =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_transaction('
              {
                "type": "transaction",
                "id": "bundle-transaction",
                "resourceType": "Bundle",
                "entry": [
                  {
                    "request": {
                      "url": "\/Patient\/id1",
                      "method": "DELETE"
                    }
                  },
                  {
                    "request": {
                      "url": "\/Patient\/id2",
                      "method": "DELETE"
                    }
                  }
                ]
              }
            ');
          ''')[0].fhir_transaction
        )

      assert.equal(transaction.resourceType, 'OperationOutcome')
      assert.equal(transaction.issue[0].severity, 'error')
      assert.equal(transaction.issue[0].code, 'not-found')
      assert.equal(
        transaction.issue[0].diagnostics,
        'Resource Id "id2" does not exist'
      )

      search =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_search('
              {"resourceType": "Patient", "queryString": "_id=id1"}
            ');
          ''')[0].fhir_search
        )

      assert.equal(search.entry.length, 1)
