search = require('../../src/fhir/search_string')
test = require('../helpers.coffee')

assert = require('assert')

testCases = [
  {
    resource: {
      resourceType: 'Patient'
      name: [
        {
          given: ['Niccolò', 'Great']
          family: ['Paganini']
          prefix: ['Music']
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
    },
    specs: [
      {
        path: ['Patient', 'name']
        elementType: 'HumanName'
        result: ['^^Niccolo$$', '^^Great$$', '^^Music$$', '^^Paganini$$', '^^Niky$$', '^^Pogy$$']
        order: 'paganini0niccolò0great0music'
      }
      {
        path: ['Patient', 'address', 'city']
        elementType: 'string'
        result: ['^^PleasantVille$$','^^Xtown$$']
        order: 'pleasantville'
      }
      {
        path: ['Patient', 'address']
        elementType: 'Address'
        result: ['^^Vic$$', '^^PleasantVille$$', '^^Rainbow$$', '^^534 Erewhon St$$']
        order: '0pleasantville0vic0rainbow0534 erewhon st039990'
      }
    ]
  },
  { # tables with PostgreSQL reserved name <https://github.com/fhirbase/fhirbase-plv8/issues/77>
    resource: {
      resourceType: 'Task'
      foo: 'bar'
    },
    specs: [
      {
        path: ['Task', 'foo']
        elementType: 'string'
        result: 'bar'
        order: 'bar'
      }
    ]
  }
]

describe "extract_as_string", ->
  testCases.forEach (testCase)->
    testCase.specs.forEach (spec)->
      it JSON.stringify(spec.path) + ' : ' + spec.elementType, ->
        metas = [
            {path: ['Patient', 'unknownPath'], elementType: spec.elementType}
            {path: spec.path, elementType: spec.elementType}]
        res = search.fhir_extract_as_string({}, testCase.resource, metas)
        for str in spec.result
          assert(res.indexOf(str) > -1, "#{str} not in #{res}")
        order = search.fhir_sort_as_string({}, testCase.resource, metas)
        assert.deepEqual(order, spec.order)
