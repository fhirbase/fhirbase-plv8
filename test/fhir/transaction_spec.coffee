plv8 = require('../../plpl/src/plv8')
transaction = require('../../src/fhir/transaction')
assert = require('assert')
helpers = require('../helpers.coffee')
search = require('../../src/fhir/search')
crud = require('../../src/core/crud')
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
      schema.create_storage(plv8, type)
      schema.truncate_storage(plv8, type)

      for res in fixtures
        crud.create(plv8, res)

  transactionExamples.examples.forEach (e, index) ->
    it e.desc, ->
      e.before.forEach (i) ->
        result = search.search(plv8, i.search)
        assert.equal(i.total, result.total)

      trResult = transaction.execute(plv8, e.transaction)

      e.after.forEach (i) ->
        result = search.search(plv8, i.search)
        assert.equal(i.total, result.total)
