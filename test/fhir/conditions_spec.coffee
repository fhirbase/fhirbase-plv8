cond = require('../../src/fhir/conditions')
honey = require('../../src/honey')
assert = require('assert')
lang = require('../../src/lang')


test = require('../helpers.coffee')
specs = test.loadYaml("#{__dirname}/conditions_spec.yaml")

describe "Build conditions", ()->
  specs.forEach (spec)->
    it JSON.stringify(spec.query), ()->
      assert.deepEqual(cond.condition(spec.query), spec.result)
      console.log honey(select: [':*'], from: ['patient'], where: spec.result)


# search.search_sql('Patient', 'name=ivan&given=ivanov')
