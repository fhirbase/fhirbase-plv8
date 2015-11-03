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

# console.log plv8.execute("SET search_path='user1';")
# console.log plv8.execute("SHOW search_path;")

FILTER = 'date'

fs.readdirSync("#{__dirname}/search").filter(match(FILTER)).forEach (yml)->
  spec = test.loadYaml("#{__dirname}/search/#{yml}")
  describe spec.title, ->
    before ->
      plv8.execute("SET plv8.start_proc = 'plv8_init'")
      for res in spec.resources
        schema.create_storage(plv8, res)
        schema.truncate_storage(plv8, res)

      for res in spec.fixtures
        crud.create_resource(plv8, res)

      for idx in (spec.indices or [])
        # search.unindex_parameter(plv8, idx)
        search.index_parameter(plv8, idx)

      for res in spec.resources
        search.analyze_storage(plv8, resourceType: res)

    spec.queries.forEach (q)->
      it "#{JSON.stringify(q.query)}", ->

        plv8.execute "SET enable_seqscan = OFF;" if q.indexed

        res = search.search(plv8, q.query)
        explain = JSON.stringify(search.explain_search(plv8, q.query))

        # console.log(JSON.stringify(res))

        plv8.execute "SET enable_seqscan = ON;" if q.indexed

        if q.total
          assert.equal(res.total, q.total)

        (q.probes || []).forEach (probe)->
          assert.equal(get_in(res, probe.path), probe.result)

         # console.log(explain)

        if q.indexed
          assert(explain.indexOf("Index Cond") > -1, "Should be indexed but #{explain}") 
