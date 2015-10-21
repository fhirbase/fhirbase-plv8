params = require('../../src/fhir/expand_params')
index = require('../../src/fhir/meta_index')
meta_fs = require('../../src/fhir/meta_fs')

test = require('../helpers.coffee')

assert = require("assert")

idx = index.new({}, meta_fs.getter)

specs = test.loadEdn("#{__dirname}/expand_params_spec.edn")

describe "Params with meta", ->
   specs.forEach (spec)->
     it JSON.stringify(spec.query), ->
       assert.deepEqual(params.expand(idx, spec.query), spec.result)
