plv8 = require('../../plpl/src/plv8')
transaction = require('../../src/fhir/transaction')
assert = require('assert')
helpers = require('../helpers.coffee')

describe 'transaction test', ()->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'should process valid transation', ->
    response = transaction.transaction(plv8, null)
    assert.equal('Bundle', response.resourceType)
    assert.equal('bundle-transaction', response.id)
    assert.equal('transaction-response', response.type)
    assert.deepEqual([], response.entry)
    console.log (helpers.loadJson(("#{__dirname}/fixtures/transaction.json")))
