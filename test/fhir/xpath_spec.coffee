xpath = require('../../src/fhir/xpath')
assert = require("assert")
test = require('../helpers.coffee')

specs = test.loadYaml("#{__dirname}/xpath_spec.yaml", 'utf8')

describe "Text Xpath", ()->
  for spec in specs.xpaths
    it "xpath #{spec.query}", ()->
      assert.deepEqual(xpath.parse(spec.query), spec.result)


# xpath.get_in(pt,[['identifier', 'value']]) # ['12345', '777']

describe "xpath: get_in", ()->
  for  spec in specs.extracts
    it "#{spec.query.join('/')}", ()->
      assert.deepEqual(xpath.get_in(specs.patient, [spec.query]), spec.result)
