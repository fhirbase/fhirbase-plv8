assert = require('assert')
plv8 = require('../../plpl/src/plv8')
fhirVersion = require('../../src/fhir/fhir_version')

describe 'Fhirbase should know', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'FHIR version', ->
    version = fhirVersion.fhir_version(plv8)
    assert.equal(
      !!version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )
