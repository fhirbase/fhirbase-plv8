search = require('../../src/fhir/search_reference')
test = require('../helpers.coffee')

assert = require('assert')

testCases = [
  {
    resource: {
      resourceType: 'Encounter'
      patient:
        reference: 'Patient/1'
    },
    specs: [
      {
        path: ['Encounter', 'patient']
        elementType: 'Reference'
        result: ['1', 'patient/1']
      }
    ]
  },
  { # tables with PostgreSQL reserved name <https://github.com/fhirbase/fhirbase-plv8/issues/77>
    resource: {
      resourceType: 'Task'
      foo:
        reference: 'Foo/1'
    },
    specs: [
      {
        path: ['Task', 'foo']
        elementType: 'Reference'
        result: ['1', 'foo/1']
      }
    ]
  }
]

describe "extract_as_reference", ->
  testCases.forEach (testCase)->
    testCase.specs.forEach (spec)->
      it JSON.stringify(spec.path), ->
        res = search.fhir_extract_as_reference(
          {}, testCase.resource,
          [
            {path: ['Task', 'unknownPath'], elementType: spec.elementType}
            {path: spec.path, elementType: spec.elementType}
          ]
        )
        assert.deepEqual(res, spec.result)
