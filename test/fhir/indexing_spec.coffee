idx = require('../../src/fhir/indexing')
test = require('../helpers.coffee')

assert = require("assert")

specs = test.loadYaml("#{__dirname}/indexing_spec.yaml")


for k,sampels of specs
  describe "INDEXING #{k}", ()->
    for spec in sampels
     it JSON.stringify(spec.query), ()->
       query = spec.query
       res = idx[k]({},query.resource, query.path, query.element_type)
       assert.deepEqual(res, spec.result)
