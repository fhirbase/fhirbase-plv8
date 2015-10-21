qs = require('../../src/fhir/query_string')
test = require('../helpers.coffee')
assert = require("assert")

specs = test.loadEdn("#{__dirname}/query_string_spec.edn")

describe "Params with meta", ->
   specs.forEach ([q, expected])->
     it JSON.stringify(q), ->
       res = qs.parse.apply(null, q)
       assert.deepEqual(res, expected)
