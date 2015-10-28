plv8 = require('../../plpl/src/plv8')
transaction = require('../../src/fhir/transaction')
assert = require('assert')
helpers = require('../helpers.coffee')
search = require('../../src/fhir/search')
schema = require('../../src/core/schema')

planExamples = helpers.loadYaml("#{__dirname}/fixtures/transaction_plans.yml")

transactionExamples = helpers.loadYaml("#{__dirname}/fixtures/transaction_examples.yml")

describe 'transaction plans', ->
  planExamples.forEach (e, index) ->
    it "should generate right plan for bundle ##{index}", ->
      plan = transaction.makePlan(e.bundle)
      assert.deepEqual(e.plan, plan)

describe 'transaction execution', ->
  transactionExamples.forEach (e, index) ->
    it "should correctly execute transaction ##{index}", ->
      e.before.forEach (i) ->
        result = search.search(plv8, i.search)
        assert.equal(i.total, result.total)

      trResult = transaction.execute(plv8, i.transaction)

      e.after.forEach (i) ->
        result = search.search(plv8, i.search)
        assert.equal(i.total, result.total)
