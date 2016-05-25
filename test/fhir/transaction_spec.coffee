plv8 = require('../../plpl/src/plv8')
transaction = require('../../src/fhir/transaction')
assert = require('assert')
helpers = require('../helpers.coffee')
search = require('../../src/fhir/search')
crud = require('../../src/fhir/crud')
schema = require('../../src/core/schema')

planExamples = helpers.loadYaml("#{__dirname}/fixtures/transaction_plans.yml")

transactionExamples = helpers.loadYaml("#{__dirname}/fixtures/transaction_examples.yml")

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
    crud.fhir_create_resource(plv8,
      resource: {resourceType: 'Patient', name: [{family: ['Foo bar']}]})

  it 'search', ->
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
    assert.equal(t.entry[0].resourceType, 'Bundle')
    assert.equal(t.entry[0].type, 'searchset')
    assert.equal(t.entry[0].total, 1)
    assert.equal(t.entry[0].entry[0].resource.resourceType, 'Patient')
    assert.equal(t.entry[0].entry[0].resource.name[0].family[0], 'Foo bar')

  it 'Transactions are not rolled back on failure #112', ->
    schema.fhir_create_storage(plv8, {"resourceType": "Patient"})
    schema.fhir_truncate_storage(plv8, {"resourceType": "Patient"})

    crud.fhir_create_resource(plv8,
      {
        "allowId": true,
        "resource": {
          "id": "id1",
          "resourceType": "Patient",
          "name": [{"given": ["Patient 1"]}]
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
              "url": "\/Patient\/id2",
              "method": "DELETE"
            }
          }
        ]
      }
    )

    search = search.fhir_search(plv8,
      {"resourceType": "Patient", "queryString": "_id=id1"})

    assert.equal(search.entry.length, 1)
