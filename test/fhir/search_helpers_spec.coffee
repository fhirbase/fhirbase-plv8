helpers = require('../../src/fhir/search_helpers')
test = require('../helpers.coffee')

assert = require('assert')

specs = [
  {
    query: {resourceType: 'Patient', queryString: 'name=ups', count: 10}
    result: [
      {relation: 'self', url: 'Patient/name=ups'}
    ]
  }
]

describe "Helpers", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.query), -> 
      res = helpers.search_links(spec.query, spec.query.count)
      assert.deepEqual(res, spec.result)
