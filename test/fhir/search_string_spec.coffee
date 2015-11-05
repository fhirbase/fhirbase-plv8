search = require('../../src/fhir/search_string')
test = require('../helpers.coffee')

assert = require('assert')

resource =
  resourceType: 'Patient'
  name: [
    {
      given: ['Niccolò', 'Great']
      family: ['Paganini']
      middle: ['Music']
    }
    {
      given: ['Niky']
      family: ['Pogy']
    }
  ]
  address: [
    {
      use: 'home'
      type: 'both'
      line: ["534 Erewhon St"]
      city: 'PleasantVille'
      district: 'Rainbow'
      state: 'Vic'
      postalCode: '3999'
    }
    {
      use: 'work'
      type: 'both'
      line: ["432 Hill Bvd"]
      city: 'Xtown'
      state: 'CA'
      postalCode: '9993'
    }
  ]

specs = [
  {
    path: ['Patient', 'name']
    elementType: 'HumanName'
    result: ['^^Niccolo$$', '^^Great$$', '^^Music$$', '^^Paganini$$', '^^Niky$$', '^^Pogy$$']
  }
  {
    path: ['Patient', 'address', 'city']
    elementType: 'string'
    result: ['^^PleasantVille$$','^^Xtown$$']
  }
  {
    path: ['Patient', 'address']
    elementType: 'Address'
    result: ['^^Vic$$', '^^PleasantVille$$', '^^Rainbow$$', '^^534 Erewhon St$$']
  }
]

describe "extract_as_token", ->
  specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      res = search.fhir_extract_as_string({}, resource, spec.path, spec.elementType)
      for str in spec.result
        assert(res.indexOf(str) > -1, "#{str} not in #{res}")
