date = require('../../src/fhir/date')
assert = require('assert')

test = require('../helpers.coffee')
specs = test.loadYaml("#{__dirname}/date_spec.yaml")

describe "Test fhir.date/to_range", ()->
  specs.forEach ([k,v])->
    it "#{k} -> #{v}", ()->
      assert.equal(date.to_range(k), v)

      d1 = new Date()
      for _ in [0..100000]
        date.to_range(k)
      d2 = new Date()

      console.log "#{k} Time "+(d2-d1)+"ms"

