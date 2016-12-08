qs = require('../../src/fhir/query_string')
test = require('../helpers.coffee')
assert = require("assert")

specs = test.loadEdn("#{__dirname}/query_string_spec.edn")

describe "Params with meta", ->
   specs.forEach ([q, expected])->
     it JSON.stringify(q), ->
       res = qs.parse.apply(null, q)
       assert.deepEqual(res, expected)

describe "issue # 169", ->
  it.only 'test', ->
    res = qs.parse("Patient", "_count=50&name=%D0%9C%D0%B8%D1%85%D0%B0%D0%B8%D0%BB")
    console.log(JSON.stringify(res, null, 2))
