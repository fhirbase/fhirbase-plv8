date = require('../../src/fhir/date')
assert = require('assert')

test = require('../helpers.coffee')
specs = test.loadYaml("#{__dirname}/date_spec.yaml")

specs.forEach ([meth, tests])->
  describe "Test fhir.date/#{meth}", ()->
    tests.forEach ([k,v])->
      it "#{k} -> #{v}", ()->
        assert.equal(date[meth](k), v)

        d1 = new Date()
        for _ in [0..10000]
          date[meth](k)
        d2 = new Date()
        console.log "#{meth}(#{k}) Time of 10K ops #{(d2-d1)} ms"

