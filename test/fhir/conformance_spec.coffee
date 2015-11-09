conf = require('../../src/fhir/conformance')
schema = require('../../src/core/schema')
plv8 = require('../../plpl/src/plv8')
test = require('../helpers.coffee')
assert = require('assert')


describe "Conformance", ->
  it "elements", ->
   schema.fhir_create_storage(plv8, resourceType: 'NutritionOrder')
   subj =  conf.fhir_conformance(plv8, {somekey: 'somevalue'})
   assert.equal(subj.somekey, 'somevalue')
   assert.equal(subj.rest[0].resource.filter((r)-> r.type == 'NutritionOrder').length, 1)

