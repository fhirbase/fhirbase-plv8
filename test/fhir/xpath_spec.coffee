xpath = require('../../src/fhir/xpath')
assert = require("assert")
test = require('../helpers.coffee')

specs = test.loadYaml("#{__dirname}/xpath_spec.yaml", 'utf8')

describe "fhir.xpath: parase", ()->
  for spec in specs.xpaths
    it "xpath #{spec.query}", ()->
      assert.deepEqual(xpath.parse(spec.query), spec.result)


# xpath.get_in(pt,[['identifier', 'value']]) # ['12345', '777']

describe "fhir.xpath: get_in", ()->
  for  spec in specs.extracts
    it "#{spec.query.join('/')}", ()->
      assert.deepEqual(xpath.get_in(specs.patient, [spec.query]), spec.result)

describe "get_in false value", () ->
  it "should return array containing false value", () ->
    assert.deepEqual([false], xpath.get_in(specs.patient, [["Patient", "active"]]))
