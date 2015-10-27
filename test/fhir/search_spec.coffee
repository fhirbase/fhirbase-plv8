search = require('../../src/fhir/search')
schema = require('../../src/core/schema')
crud = require('../../src/core/crud')
honey = require('../../src/honey')
plv8 = require('../../plpl/src/plv8')
fs = require('fs')
test = require('../helpers.coffee')

assert = require('assert')

# plv8.debug = true
get_in = (obj, path)->
  cur = obj
  cur = cur[item] for item in path when cur
  cur

fs.readdirSync("#{__dirname}/search").forEach (yml)->
  spec = test.loadYaml("#{__dirname}/search/#{yml}")
  describe spec.title, ->
    before ->
      plv8.execute("SET plv8.start_proc = 'plv8_init'")
      for res in spec.resources
        schema.create_storage(plv8, res)
        schema.truncate_storage(plv8, res)

      for res in spec.fixtures
        crud.create(plv8, res)

    spec.queries.forEach (q)->
      it "#{JSON.stringify(q.query)}", ->
        res = search.search(plv8, q.query)
        if q.total
          assert.equal(res.total, q.total)
        q.probes.forEach (probe)->
          assert.equal(get_in(res, probe.path), probe.result)

comment = ->
  test = require('../helpers.coffee')

  specs = test.loadYaml("#{__dirname}/search_spec.yaml")


  its = ([res,q] for res, q of specs.queries)

  # plv8.debug = true

  describe "Seatch integration test", ()->
    before ->
      plv8.execute("SET plv8.start_proc = 'plv8_init'")
      for res in specs.resources
        schema.create_storage(plv8, res)
        schema.truncate_storage(plv8, res)

      for res in specs.fixtures
        crud.create(plv8, res)

    its.forEach ([resourceType, queries])->
      queries.forEach (q)->
        it "#{resourceType} :  #{q.query}", ->
          res = search.search(plv8, resourceType: resourceType, queryString: q.query)
          if q.total
            assert.equal(res.total, q.total)
          q.probes.forEach (probe)->
            assert.equal(get_in(res, probe.path), probe.result)
