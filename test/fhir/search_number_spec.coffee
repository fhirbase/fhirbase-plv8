search = require('../../src/fhir/search_number')
test = require('../helpers.coffee')

assert = require('assert')

resource =
  resourceType: 'Encounter'
  length: '10'
  valueQuantity:
    value: 100
    unit: 'ml'
    system: 'metric'


specs = [
  {
    path: ['Encounter', 'length']
    elementType: 'integer'
    result: '10'
  }
  {
    path: ['Encounter', 'valueQuantity']
    elementType: 'Quantity'
    result: '100'
  }
]

describe "extract_as_token", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      res = search.fhir_extract_as_number({}, resource, spec.path, spec.elementType)
      assert.equal(res, spec.result)
