assert = require('assert')
plv8 = require('../../plpl/src/plv8')
fhirbaseVersion = require('../../src/core/fhirbase_version')

describe 'Fhirbase should know his', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'version', ->
    version = fhirbaseVersion.fhirbase_version(plv8)
    assert.equal(
      !!version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )

  it 'release date', ->
    version = fhirbaseVersion.fhirbase_release_date(plv8)
    assert.equal(
      !!version.match(/-?[0-9]{4}(-(0[1-9]|1[0-2])(-(0[0-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)?/),
      true
    )
