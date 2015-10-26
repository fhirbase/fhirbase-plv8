plv8 = require('../../plpl/src/plv8')
transaction = require('../../src/fhir/transaction')
assert = require('assert')
helpers = require('../helpers.coffee')
search = require('../../src/fhir/search')
schema = require('../../src/core/schema')

describe 'transaction test', ()->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    for res in ['patient']
      schema.create_storage(plv8, res)
      schema.truncate_storage(plv8, res)

  it 'should process valid transation', ->
    bundle = helpers.loadJson(("#{__dirname}/fixtures/transaction.json"))
    response = transaction.transaction(plv8, bundle)
    patients = search.search(plv8, resourceType: 'Patient', queryString: 'active=true')
    assert.equal(2, patients.total)





    assert.equal('Bundle', response.resourceType)
    assert.equal('bundle-transaction', response.id)
    assert.equal('transaction-response', response.type)
    assert.deepEqual([], response.entry)
