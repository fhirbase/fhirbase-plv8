search = require('../../src/fhir/search_date')
test = require('../helpers.coffee')
plv8 = require('../../plpl/src/plv8')
assert = require('assert')

value_specs = [
  {
    args:   ['lt', '1980']
    result: ['$tstzrange', '-infinity', '1980-01-01', '()']
  }
  {
    args:   ['le', '1980']
    result: ['$tstzrange', '-infinity', '1981-01-01', '()']
  }
  {
    args:   ['gt', '1980']
    result: ['$tstzrange', '1981-01-01', 'infinity', '()']
  }
  {
    args:   ['ge', '1980']
    result: ['$tstzrange', '1980-01-01', 'infinity', '()']
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

metas = [
  {
    path: ['Observation', 'unknownPath']
    elementType: 'dateTime'
  }
  {
    path: ['Observation', 'effectiveDateTime']
    elementType: 'dateTime'
  }
  {
    path: ['Observation', 'effectivePeriod']
    elementType: 'Period'
  }
]

metas_epoch_specs = [
  {
    resource: {effectiveDateTime: '1993-09-21T15:25:34.300Z'}
    assert: {
      lower: 748625134.3
      upper: 748625134.30099
    }
  }
  {
    resource: {effectivePeriod: {
      start: '1993-09-21T15:25:34.300Z'
      end: '1994-09-21T15:25:34.300Z'}}
    assert: {
      lower: 748625134.3
      upper: 780161134.30099
    }
  }
  {
    resource: {}
    assert: {
      lower: null
      upper: null
    }
  }
]

describe "extract_as_metas_epoch", ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  metas_epoch_specs.forEach (spec)->
    it JSON.stringify(spec.resource) + " >> [" + spec.assert.lower + "," + spec.assert.upper + "]", ->
      lower = search.fhir_extract_as_epoch_lower(
        plv8,
        spec.resource,
        metas)
      assert.equal(lower, spec.assert.lower)
      upper = search.fhir_extract_as_epoch_upper(
        plv8,
        spec.resource,
        metas)
      assert.equal(upper, spec.assert.upper)
