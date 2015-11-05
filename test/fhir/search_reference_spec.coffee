search = require('../../src/fhir/search_reference')
test = require('../helpers.coffee')

assert = require('assert')

resource =
  resourceType: 'Encounter'
  patient:
    reference: 'Patient/1'

specs = [
  {
    path: ['Encounter', 'patient']
    elementType: 'Reference'
    result: ['1', 'patient/1']
  }
]
describe "extract_as_reference", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      res = search.fhir_extract_as_reference({}, resource, spec.path, spec.elementType)
      assert.deepEqual(res, spec.result)
