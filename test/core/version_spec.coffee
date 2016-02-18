plv8 = require('../../plpl/src/plv8')
assert = require('assert')

describe 'CORE: version', ->
  beforeEach ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'fhirbase should know his version', ->
    version = plv8.execute("SELECT fhirbase_version()")[0].fhirbase_version
    assert.equal(
      !!version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )
