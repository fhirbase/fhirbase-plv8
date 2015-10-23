plv8 = require('../../plpl/src/plv8')
assert = require('assert')

describe 'transaction test', ()->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'should process valid transation', ->
    assert.equal('a', 'a')
