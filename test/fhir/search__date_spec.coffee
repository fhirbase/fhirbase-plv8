search = require('../../src/fhir/search_date')
test = require('../helpers.coffee')
plv8 = require('../../plpl/src/plv8')
assert = require('assert')

extract_specs = [
  {
    resource: {birthDate: '1980'}
    assert: {
      path: ['Patient', 'birthDate']
      elementType: 'date'
      result: '[1980-01-01,1981-01-01)'
    }
  }
  {
    resource: {admitDateTime: '2015-01-02'}
    assert: {
      path: ['Patient', 'admitDateTime']
      elementType: 'dateTime'
      result: '[2015-01-02,2015-01-02T23:59:59.99999]'
    }
  }
  { #related to bugs with PostgreSQL reserved key words <https://github.com/fhirbase/fhirbase-plv8/issues/77>, <https://github.com/fhirbase/fhirbase-plv8/issues/88>, <http://www.postgresql.org/docs/current/static/sql-keywords-appendix.html#KEYWORDS-TABLE>
    resource: {date: '2015-01-02'}
    assert: {
      path: ['Task', 'date']
      elementType: 'dateTime'
      result: '[2015-01-02,2015-01-02T23:59:59.99999]'
    }
  }
]

describe "extract_as_date", ->
  extract_specs.forEach (spec)->
    it JSON.stringify(spec.assert.path || "unknown"), ->
      res = search.fhir_extract_as_daterange(
        {},
        spec.resource,
        spec.assert.path,
        spec.assert.elementType)
      assert.deepEqual(res, spec.assert.result)

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

epoch_specs = [
  {
    resource: {effectiveDateTime: '1993-09-21T15:25:34.300Z'}
    assert: {
      path: ['Observation', 'effectiveDateTime']
      elementType: 'dateTime'
      lower: 748625134.3
      upper: 748625134.3
    }
  }
  {
    resource: {}
    assert: {
      path: ['Observation', 'effectiveDateTime']
      elementType: 'dateTime'
      lower: null
      upper: null
    }
  }
  {
    resource: {effectivePeriod: {
      start: '1993-09-21T15:25:34.300Z'
      end: '1994-09-21T15:25:34.300Z'}}
    assert: {
      path: ['Observation', 'effectivePeriod']
      elementType: 'Period'
      lower: 748625134.3
      upper: 780161134.3
    }
  }
]

describe "extract_as_epoch", ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  epoch_specs.forEach (spec)->
    it JSON.stringify(spec.assert.path) + " : " + spec.assert.elementType + " >> [" + spec.assert.lower + "," + spec.assert.upper + "]", ->
      lower = search.fhir_extract_as_epoch_lower(
        plv8,
        spec.resource,
        spec.assert.path,
        spec.assert.elementType)
      assert.equal(lower, spec.assert.lower)
      upper = search.fhir_extract_as_epoch_upper(
        plv8,
        spec.resource,
        spec.assert.path,
        spec.assert.elementType)
      assert.equal(upper, spec.assert.upper)
