norm = require('../../src/fhir/normalize_params')
test = require('../helpers.coffee')

assert = require("assert")

specs = test.loadYaml("#{__dirname}/normalize_params_spec.yaml", 'utf8')

describe "Params with meta", ()->
   it "params", ()->
     for spec in specs
       console.log(norm.normalize({params: spec.query}))
       assert.deepEqual(norm.normalize({params: spec.query}).params, spec.result)


