helpers = require('../../src/fhir/search_helpers')
test = require('../helpers.coffee')

assert = require('assert')

specs = [
  {
    query: {resourceType: 'Patient', queryString: 'name=ups&count=10', total: 15}
    result: [
      {relation: 'self', url: 'Patient/name=ups&count=10&page=1'}
      {relation: 'next', url: 'Patient/name=ups&count=10&page=2'}
      {relation: 'last', url: 'Patient/name=ups&count=10&page=2'}
    ]
  }
  {
    query: {resourceType: 'Patient', queryString: 'name=ups&count=10', total: 9}
    result: [
      {relation: 'self', url: 'Patient/name=ups&count=10&page=1'}
      {relation: 'last', url: 'Patient/name=ups&count=10&page=1'}
    ]
  }
  {
    query: {resourceType: 'Patient', queryString: 'name=ups&count=10&page=5', total: 155}
    result: [
      {relation: 'self', url: 'Patient/name=ups&count=10&page=5'}
      {relation: 'next', url: 'Patient/name=ups&count=10&page=6'}
      {relation: 'previous', url: 'Patient/name=ups&count=10&page=4'}
      {relation: 'last', url: 'Patient/name=ups&count=10&page=16'}
    ]
  }
]

describe "Helpers", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.query), -> 
      res = helpers.search_links(spec.query, spec.query.total)
      assert.deepEqual(res, spec.result)
