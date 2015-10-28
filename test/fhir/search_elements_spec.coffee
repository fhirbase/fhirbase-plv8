test = require('../helpers.coffee')
assert = require('assert')
elements = require('../../src/fhir/search_elements')

specs = test.loadYaml("#{__dirname}/search_elements_spec.yaml", 'utf8')

describe "CORE: param to element", ()->
  specs.param_to_elements.forEach (x)->
    it x.args, ()->
      assert.deepEqual(elements.param_to_elements(x.args), x.result)

