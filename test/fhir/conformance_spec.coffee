conf = require('../../src/fhir/conformance')
schema = require('../../src/core/schema')
plv8 = require('../../plpl/src/plv8')
test = require('../helpers.coffee')
assert = require('assert')


describe "Conformance", ->
  it "elements", ->
    schema.fhir_create_storage(plv8, resourceType: 'NutritionOrder')
    conformance = conf.fhir_conformance(plv8, {somekey: 'somevalue'})
    assert.equal(conformance.somekey, 'somevalue')
    assert.equal(
      conformance.rest[0].resource.filter(
        (r)-> r.type == 'NutritionOrder'
      ).length,
      1
    )
    assert.equal(
      !!conformance.fhirVersion.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )
    assert.equal(
      !!conformance.version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )
    assert.equal(
      !!conformance.software.version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )
    assert.equal(
      !!conformance.software.releaseDate.match(/-?[0-9]{4}(-(0[1-9]|1[0-2])(-(0[0-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)?/),
      true
    )
