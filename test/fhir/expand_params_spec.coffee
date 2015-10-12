params = require('../../src/fhir/expand_params')
index = require('../../src/fhir/meta_index')
meta_fs = require('../../src/fhir/meta_fs')

test = require('../helpers.coffee')

assert = require("assert")

idx = index.new({}, meta_fs.getter)

specs = test.loadYaml("#{__dirname}/expand_params_spec.yaml", 'utf8')

describe "Params with meta", ()->
   it "params", ()->
     for spec in specs
       assert.deepEqual(params._expand(idx, spec.query), spec.result)
