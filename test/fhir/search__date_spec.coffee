search = require('../../src/fhir/search_date')
test = require('../helpers.coffee')

assert = require('assert')

resource =
  birthDate: '1980'
  admitDateTime: '2015-01-02'

extract_specs = [
  {
    path: ['Patient', 'birthDate']
    elementType: 'date'
    result: '[1980-01-01,1981-01-01)'
  }
  {
    path: ['Patient', 'admitDateTime']
    elementType: 'dateTime'
    result: '[2015-01-02,2015-01-02T23:59:59.99999]'
  }
]

describe "extract_as_date", ->
  extract_specs.forEach (spec)->
    it JSON.stringify(spec.path), ->
      res = search.extract_as_daterange({}, resource, spec.path, spec.elementType)
      assert.deepEqual(res, spec.result)

      
value_specs = [
  {
    args:   ['lt', '1980']
    result: ['$tstzrange', '-infinity', '1981-01-01', '()']
  }
  {
    args:   ['le', '1980']
    result: ['$tstzrange', '-infinity', '1981-01-01', '()']
  }
  {
    args:   ['gt', '1980']
    result: ['$tstzrange', '1980-01-01', 'infinity', '[)']
  }
  {
    args:   ['ge', '1980']
    result: ['$tstzrange', '1980-01-01', 'infinity', '[)']
  }
  {
    args:   ['eq', '1980']
    result: ['$tstzrange', '1980-01-01', '1981-01-01', '[)']
  }
]

describe "extract_as_date", ->
  value_specs.forEach (spec)->
    it JSON.stringify(spec.args) + " >> " + JSON.stringify(spec.result), ->
      res = search.value_to_range.apply(null, spec.args)
      assert.deepEqual(res, spec.result)
