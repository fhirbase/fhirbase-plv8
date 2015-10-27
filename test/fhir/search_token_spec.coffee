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

specs = [
  {
    path: ['Patient', 'active']
    elementType: 'boolean'
    result: ['true']
  }
  {
    path: ['Patient', 'identifier']
    elementType: 'Identifier'
    result: ['1', 'ssn|1', '2', 'mrn|2']
  }
  {
    path: ['Patient', 'gender']
    elementType: 'code'
    result: ['male']
  }
  {
    path: ['Patient', 'gender']
    elementType: 'string'
    result: ['male']
  }
  {
    path: ['Patient', 'type']
    elementType: 'Coding'
    result: ['ups', 'dups|ups']
  }
  {
    path: ['Patient', 'communication', 'language']
    elementType: 'CodeableConcept'
    result: ['us', 'lang|us', 'en', 'world|en']
  }
  {
    path: ['Patient', 'provider']
    elementType: 'Reference'
    result: ['Provider/1']
  }
  {
    path: ['Patient', 'telecom']
    elementType: 'ContactPoint'
    result: ['444', 'phone|444', 'a@b.com', 'email|a@b.com']
  }
]
describe "extract_as_token", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      res = search.extract_as_token({}, resource, spec.path, spec.elementType)
      assert.deepEqual(res, spec.result)
