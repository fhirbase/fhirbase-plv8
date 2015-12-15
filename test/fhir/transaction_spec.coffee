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

    for type, fixtures of transactionExamples.fixtures
      schema.fhir_create_storage(plv8, resourceType: type)
      schema.fhir_truncate_storage(plv8,  resourceType: type)

      for res in fixtures
        crud.fhir_create_resource(plv8, resource: res)

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
