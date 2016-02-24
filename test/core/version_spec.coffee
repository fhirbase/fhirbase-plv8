assert = require('assert')
plv8 = require('../../plpl/src/plv8')
version = require('../../src/core/version')

describe 'CORE: version', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'fhirbase should know his version', ->
    version = version.fhirbase_version(plv8)
    assert.equal(
      !!version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )
