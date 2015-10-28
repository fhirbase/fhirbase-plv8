search = require('../../src/fhir/search_token')
test = require('../helpers.coffee')

assert = require('assert')

resource =
  active: true
  gender: 'male'
  type:
    code: 'ups'
    system: 'dups'
    text: 'hops'
  telecom: [
    {use: 'home', system: 'phone', value: 444}
    {use: 'work', system: 'email', value: 'a@b.com'}
  ]
  communication: [
    {language: {coding: [{code: 'us', system: 'lang'}, {code: 'en', system: 'world'}]}}
  ]
  provider:
    reference: 'Provider/1'
  identifier: [
    {system: 'ssn', value: '1'}
    {system: 'mrn', value: '2'}
  ]
  value: 
    value: 10
    unit: "mg"
    system: "http://unitsofmeasure.org"
    code: "[mg]"

specs = [
  {
    path: ['Resource', 'active']
    elementType: 'boolean'
    result: ['true']
  }
  {
    path: ['Resource', 'identifier']
    elementType: 'Identifier'
    result: ['1', 'ssn|1', '2', 'mrn|2']
  }
  {
    path: ['Resource', 'gender']
    elementType: 'code'
    result: ['male']
  }
  {
    path: ['Resource', 'gender']
    elementType: 'string'
    result: ['male']
  }
  {
    path: ['Resource', 'type']
    elementType: 'Coding'
    result: ['ups', 'dups|ups']
  }
  {
    path: ['Resource', 'communication', 'language']
    elementType: 'CodeableConcept'
    result: ['us', 'lang|us', 'en', 'world|en']
  }
  {
    path: ['Resource', 'provider']
    elementType: 'Reference'
    result: ['Provider/1']
  }
  {
    path: ['Resource', 'telecom']
    elementType: 'ContactPoint'
    result: ['444', 'phone|444', 'a@b.com', 'email|a@b.com']
  }
  {
    path: ['Resource', 'value']
    elementType: 'Quantity'
    result: ['[mg]', 'mg', 'http://unitsofmeasure.org|[mg]', 'http://unitsofmeasure.org|mg']
  }
]

describe "extract_as_token", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      res = search.extract_as_token({}, resource, spec.path, spec.elementType)
      assert.deepEqual(res, spec.result)
