search = require('../../src/fhir/search_number')
test = require('../helpers.coffee')

assert = require('assert')

testCases = [
  {
    resource: {
      resourceType: 'Encounter'
      length: '10'
      valueQuantity:
        value: 100
        unit: 'ml'
        system: 'metric'
    },
    specs: [
      {
        path: ['Encounter', 'length']
        elementType: 'integer'
        result: '10'
      },
      {
        path: ['Encounter', 'valueQuantity']
        elementType: 'Quantity'
        result: '100'
      }
    ]
  },
  { # tables with PostgreSQL reserved name <https://github.com/fhirbase/fhirbase-plv8/issues/77>
    resource: {
      resourceType: 'Task'
      length: '10'
      valueQuantity:
        value: 100
        unit: 'ml'
        system: 'metric'
    },
    specs: [
      {
        path: ['Task', 'length']
        elementType: 'integer'
        result: '10'
      },
      {
        path: ['Task', 'valueQuantity']
        elementType: 'Quantity'
        result: '100'
      }
    ]
  }
]

describe "extract_as_token", ->
  testCases.forEach (testCase)->
    testCase.specs.forEach (spec)->
      it JSON.stringify(spec.path), ->
        res = search.fhir_extract_as_number(
          {}, testCase.resource, spec.path, spec.elementType
        )
        assert.equal(res, spec.result)
