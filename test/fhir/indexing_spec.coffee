idx = require('../../src/fhir/indexing')
test = require('../helpers.coffee')

assert = require("assert")

specs = test.loadYaml("#{__dirname}/indexing_spec.yaml")


for k, samples of specs
  describe "INDEXING #{k}:", ()->
    specs[k].forEach (spec)->
      key = "#{k}"
      it JSON.stringify(spec.query), ()->
        query = spec.query
        fn =  idx[key]
        unless fn
          throw new Error("No function #{k} in indexing module; #{JSON.stringify(idx)}")
        res = fn({},query.resource, query.path, query.element_type)
        assert.deepEqual(res, spec.result)
