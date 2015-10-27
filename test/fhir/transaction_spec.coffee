plv8 = require('../../plpl/src/plv8')
transaction = require('../../src/fhir/transaction')
assert = require('assert')
helpers = require('../helpers.coffee')
search = require('../../src/fhir/search')
schema = require('../../src/core/schema')

planExamples = helpers.loadYaml("#{__dirname}/fixtures/transaction_plans.yml")

# console.log "!!!!", JSON.stringify(planExamples, null, 1)

# describe 'transaction test', ()->
#   before ->
#     plv8.execute("SET plv8.start_proc = 'plv8_init'")
#     for res in ['patient']
#       schema.create_storage(plv8, res)
#       schema.truncate_storage(plv8, res)

describe 'transaction plans', ->
  planExamples.forEach (e, index) ->
    it "should generate right plan for bundle ##{index}", ->
      plan = transaction.makePlan(e.bundle)
      assert.deepEqual(e.plan, plan)
      console.log "!!!!", JSON.stringify(transaction.executePlan(plv8, plan))
