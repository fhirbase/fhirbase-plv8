cond = require('../../src/fhir/conditions')
honey = require('../../src/honey')
assert = require('assert')
lang = require('../../src/lang')


# test = require('../helpers.coffee')
# specs = test.loadEdn("#{__dirname}/conditions_spec.edn")

# describe "Build conditions", ()->
#   specs.forEach (spec)->
#     it JSON.stringify(spec.query), ()->
#       assert.deepEqual(cond.eval(spec.query), spec.result)
#       #console.log honey(select: [':*'], from: ['patient'], where: spec.result)

