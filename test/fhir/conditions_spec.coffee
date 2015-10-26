cond = require('../../src/fhir/conditions')
honey = require('../../src/honey')
assert = require('assert')
lang = require('../../src/lang')


test = require('../helpers.coffee')
specs = test.loadEdn("#{__dirname}/conditions_spec.edn")

describe "Build conditions", ()->
  specs.forEach (spec)->
    it JSON.stringify(spec.query), ()->
      assert.deepEqual(cond.condition("table", spec.query[1], spec.query[2]), spec.result)

