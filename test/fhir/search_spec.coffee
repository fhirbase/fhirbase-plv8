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

match = (x)->
  (y)-> y.indexOf(x) > -1

# plv8.debug = true

fs.readdirSync("#{__dirname}/search").filter(match('search')).forEach (yml)->
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

        (q.probes || []).forEach (probe)->
          assert.equal(get_in(res, probe.path), probe.result)
