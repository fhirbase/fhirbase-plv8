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
    order: 'true'
  }
  {
    path: ['Resource', 'identifier']
    elementType: 'Identifier'
    result: ['1', 'ssn|1', '2', 'mrn|2']
    order: 'ssn01'
  }
  {
    path: ['Resource', 'gender']
    elementType: 'code'
    result: ['male']
    order: 'male'
  }
  {
    path: ['Resource', 'gender']
    elementType: 'string'
    result: ['male']
    order: 'male'
  }
  {
    path: ['Resource', 'type']
    elementType: 'Coding'
    result: ['ups', 'dups|ups']
    order: 'dups0ups0'
  }
  {
    path: ['Resource', 'communication', 'language']
    elementType: 'CodeableConcept'
    result: ['us', 'lang|us', 'en', 'world|en']
    order: 'lang0us0'
  }
  {
    path: ['Resource', 'provider']
    elementType: 'Reference'
    result: ['Provider/1']
    order: 'Provider/1'
  }
  {
    path: ['Resource', 'telecom']
    elementType: 'ContactPoint'
    result: ['444', 'phone|444', 'a@b.com', 'email|a@b.com']
    order: 'phone0444'
  }
  {
    path: ['Resource', 'value']
    elementType: 'Quantity'
    result: ['[mg]', 'mg', 'http://unitsofmeasure.org|[mg]', 'http://unitsofmeasure.org|mg']
    order: 'http://unitsofmeasure.org0mg0[mg]'
  }
]

describe "extract_as_token", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      metas = [
        {path: ['Resource', 'unknownPath'], elementType: spec.elementType},
        {path: spec.path, elementType: spec.elementType}
      ]
      res = search.fhir_extract_as_token({}, resource, metas)
      assert.deepEqual(res, spec.result)
      order = search.fhir_sort_as_token({}, resource, metas)
      assert.deepEqual(order, spec.order)
