search = require('../../src/fhir/search_uri')
test = require('../helpers.coffee')

assert = require('assert')

testCases = [
  {
    resource: {
      resourceType: 'Resource'
      link: [
        {link: 'http://acme.org/fhir/ValueSet/123'}
        {link: 'http://acme.org/fhir/ValueSet/124'}
      ]
    },
    specs: [
      {
        path: ['Resource', 'link', 'link']
        elementType: 'uri'
        result: '^^acme.org/fhir/valueset/123$$ ^^acme.org/fhir/valueset/124$$'
      }
    ]
  },
  { # tables with PostgreSQL reserved name <https://github.com/fhirbase/fhirbase-plv8/issues/77>
    resource: {
      resourceType: 'Task'
      link: [
        {link: 'http://acme.org/fhir/ValueSet/123'}
        {link: 'http://acme.org/fhir/ValueSet/124'}
      ]
    },
    specs: [
      {
        path: ['Task', 'link', 'link']
        elementType: 'uri'
        result: '^^acme.org/fhir/valueset/123$$ ^^acme.org/fhir/valueset/124$$'
      }
    ]
  }
]

describe "extract_as_token", ->
  testCases.forEach (testCase)->
    testCase.specs.forEach (spec)->
      it JSON.stringify(spec.path), ->
        res = search.fhir_extract_as_uri(
          {}, testCase.resource, spec.path, spec.elementType
        )
        assert.equal(res, spec.result)
