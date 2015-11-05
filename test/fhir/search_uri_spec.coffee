search = require('../../src/fhir/search_uri')
test = require('../helpers.coffee')

assert = require('assert')

resource =
  resourceType: 'Resource'
  link: [
    {link: "http://acme.org/fhir/ValueSet/123"}
    {link: "http://acme.org/fhir/ValueSet/124"}
  ]

specs = [
  {
    path: ['Resource', 'link', 'link']
    elementType: 'uri'
    result: "^^acme.org/fhir/valueset/123$$ ^^acme.org/fhir/valueset/124$$"
  }
]

describe "extract_as_token", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      res = search.fhir_extract_as_uri({}, resource, spec.path, spec.elementType)
      assert.equal(res, spec.result)
