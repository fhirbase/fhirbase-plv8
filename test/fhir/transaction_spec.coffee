plv8 = require('../../plpl/src/plv8')
transaction = require('../../src/fhir/transaction')
assert = require('assert')
helpers = require('../helpers.coffee')
search = require('../../src/fhir/search')
crud = require('../../src/fhir/crud')
schema = require('../../src/core/schema')

match = helpers.match

planExamples = helpers.loadYaml("#{__dirname}/fixtures/transaction_plans.yml")

transactionExamples = helpers.loadYaml("#{__dirname}/fixtures/transaction_examples.yml")

copy = (x)-> JSON.parse(JSON.stringify(x))

describe 'transaction plans', ->
  planExamples.forEach (e, index) ->
    it "should generate right plan for bundle ##{index}", ->
      plan = transaction.makePlan(e.bundle)
      assert.deepEqual(e.plan, plan)

describe 'transaction execution', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

    schema.fhir_create_storage(plv8, resourceType: 'Encounter')

    for type, fixtures of transactionExamples.fixtures
      schema.fhir_create_storage(plv8, resourceType: type)
      schema.fhir_truncate_storage(plv8,  resourceType: type)

      for res in fixtures
        crud.fhir_create_resource(plv8, allowId: true, resource: res)

  # plv8.debug = true
  transactionExamples.examples.forEach (e, index) ->
    it e.desc, ->
      e.before.forEach (i) ->
        result = search.fhir_search(plv8, i.search)
        assert.equal(i.total, result.total, 'before:' + JSON.stringify(i))

      trResult = transaction.execute(plv8, e.transaction)

      e.after.forEach (i) ->
        result = search.fhir_search(plv8, i.search)
        assert.equal(i.total, result.total, 'after:' + JSON.stringify(i))

describe 'Transaction', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    schema.fhir_create_storage(plv8, resourceType: 'Patient')

  beforeEach ->
    schema.fhir_truncate_storage(plv8, resourceType: 'Patient')

  it 'update resource contention', ->
    created = crud.fhir_create_resource(plv8, {
      "allowId": true,
      "resource": {
        "resourceType": "Patient",
        "name": [{"given": ["Foo"]}],
        "id": "patient-id"
      }
    })

    bundle1 = {
      "resourceType":"Bundle",
      "type":"transaction",
      "entry": [
        {
          "resource": {"resourceType": "Patient", "name": [{"given":["Bar"]}]},
          "request": {
            "ifMatch":created.meta.versionId,
            "method":"PUT",
            "url":"Patient/patient-id"
          }
        }
      ]
    }

    transaction1 = transaction.fhir_transaction(plv8, bundle1)
    match(
      transaction1,
      {
        "resourceType": "Bundle",
        "type": "transaction-response",
        "entry": [
          {
            "resource": {
              "resourceType": "Patient",
              "name": [{"given": ["Bar"]}],
              "id": "patient-id",
            }
          }
        ]
      }
    )

    bundle2 = {
      "resourceType":"Bundle",
      "type":"transaction",
      "entry": [
        {
          "resource": {"resourceType": "Patient", "name": [{"given":["Xyz"]}]},
          "request": {
            "ifMatch":created.meta.versionId,
            "method":"PUT",
            "url":"Patient/patient-id"
          }
        }
      ]
    }

    transaction2 = transaction.fhir_transaction(plv8, bundle2)
    match(
      transaction2,
      {
        "resourceType": "OperationOutcome",
        "issue": [
          {
            "severity": "error",
            "code": "conflict",
            "extension": [
              {
                "url": "http-status-code",
                "valueString": "409"
              }
            ]
          }
        ]
      }
    )

  it 'search', ->
    crud.fhir_create_resource(plv8,
      resource: {resourceType: 'Patient', name: [{family: ['Foo bar']}]})

    bundle =
      resourceType: 'Bundle'
      id: 'bundle-transaction-id'
      type: 'transaction'
      entry: [
        {
          request:
            method: 'GET'
            url: '/Patient?name=Foo bar'
        }
      ]

    t = transaction.fhir_transaction(plv8, bundle)
    assert.equal(t.resourceType, 'Bundle')
    assert.equal(t.type, 'transaction-response')

    r = t.entry[0].resource
    assert.equal(r.resourceType, 'Bundle')
    assert.equal(r.type, 'searchset')
    assert.equal(r.total, 1)
    assert.equal(r.entry[0].resource.resourceType, 'Patient')
    assert.equal(r.entry[0].resource.name[0].family[0], 'Foo bar')

  it 'history && vread', ->
    res = {resourceType: 'Patient', name: [{given: ['Tim']}], id: '2345'}
    schema.fhir_truncate_storage(plv8, resourceType: 'Patient')
    created = crud.fhir_create_resource(plv8, allowId: true, resource: res)
    updated = crud.fhir_update_resource(plv8, resource: copy(created))

    bundle =
      resourceType: 'Bundle'
      id: 'bundle-transaction-id'
      type: 'transaction'
      entry: [
        {
          request:
            method: 'GET'
            url: '/Patient/2345/_history'
        },
        {
          request:
            method: 'GET'
            url: '/Patient/_history'
        },
        {
          request:
            method: 'GET'
            url: "Patient/2345/_history/#{created.meta.versionId}"
        },
        {
          request:
            method: 'GET'
            url: "Patient/2345/_history/#{updated.meta.versionId}"
        }
      ]

    t = transaction.fhir_transaction(plv8, bundle)
    assert.equal(t.resourceType, 'Bundle')
    assert.equal(t.type, 'transaction-response')

    [t.entry[0], t.entry[1]].forEach (e) ->
      r = e.resource
      assert.equal(r.resourceType, 'Bundle')
      assert.equal(r.type, 'history')
      assert.equal(r.total, 2)
      match(copy(r.entry[0].resource), copy(updated))
      match(copy(r.entry[1].resource), copy(created))

    match(copy(t.entry[2].resource), copy(created))
    match(copy(t.entry[3].resource), copy(updated))

  describe 'conditional', ->
    beforeEach ->
      schema.fhir_truncate_storage(plv8, resourceType: 'Patient')
      crud.fhir_create_resource(plv8, {
        "allowId": true,
        "resource": {
          "resourceType": "Patient",
          "name": [{"given": ["Name1"], "family": ["Foo"]}],
          "id": "id1"
        }
      })
      crud.fhir_create_resource(plv8, {
        "allowId": true,
        "resource": {
          "resourceType": "Patient",
          "name": [{"given": ["Name2"], "family": ["Bar"]}],
          "id": "id2"
        }
      })

    # Conditional update in transaction doesn't work correctly #126
    # <https://github.com/fhirbase/fhirbase-plv8/issues/126>
    it 'update', ->
      bundle = {
        "resourceType":"Bundle",
        "type":"transaction",
        "entry": [
          {
            "resource": {
              "resourceType": "Patient",
              "name": [{"given":["Name1"],"family":["aaa~aaa.1.2"]}]
            },
            "request": {"method":"PUT","url":"Patient?given=aaa~aaa.1.2"}}
          ]
        }

      match(
        transaction.fhir_transaction(plv8, bundle),
        {
          "resourceType": "Bundle",
          "type": "transaction-response",
          "entry": [
            {
              "resource": {
                "resourceType": "Patient",
                "name": [
                  {
                    "given": [
                      "Name1"
                    ],
                    "family": [
                      "aaa~aaa.1.2"
                    ]
                  }
                ]
              }
            }
          ]
        }
      )

    # Conditional delete in transaction doesn't work correctly #127
    # <https://github.com/fhirbase/fhirbase-plv8/issues/127>
    it 'delete', ->
      bundle = {
        "resourceType":"Bundle",
        "type":"transaction",
        "entry":[{
          "request":{"method":"DELETE","url":"Patient?given=Name1"}
        }]
      }

      match(
        transaction.fhir_transaction(plv8, bundle),
        {
          "resourceType": "Bundle",
          "type": "transaction-response"
        }
      )

  it 'roll back on failure', -> #related to issue #112
    schema.fhir_create_storage(plv8, {"resourceType": "Patient"})
    schema.fhir_truncate_storage(plv8, {"resourceType": "Patient"})

    ['id1', 'id2', 'id3'].forEach (id) ->
      crud.fhir_create_resource(plv8, {
        allowId: true
        resource: {
          id: id
          resourceType: "Patient"
          name: [{"given": ["John"]}]
          }
        }
      )

    t = transaction.fhir_transaction(plv8,
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
              "url": "\/Patient\/?given=John",
              "method": "DELETE"
            }
          }
        ]
      }
    )

    match(
      t,
      resourceType: 'OperationOutcome'
      issue: [{
        severity: 'error'
        code: '412'
        diagnostics: 'Precondition Failed error indicating the client\'s criteria were not selective enough. undefined'
        extension: [{
          url: 'http-status-code'
          valueString: '412'
          }]
        }]
    )

    patient = crud.fhir_read_resource(plv8,
      {"resourceType": "Patient", "id": "id1"})

    assert.equal(patient.resourceType, 'Patient')
    assert.equal(patient.id, 'id1')

  it 'report proper error message', ->
    bundle =
      type: 'transaction',
      id: 'bundle-transaction',
      resourceType: 'Bundle',
      entry: [
        request:
          url: '/Patient/id1',
          method: 'POST'
      ]

    match(
      transaction.fhir_transaction(plv8, bundle),
      resourceType: 'OperationOutcome'
      issue: [
        {
          severity: 'error',
          code: '422',
          diagnostics: 'Invalid operation POST /Patient/id1'
        }
      ]
    )
