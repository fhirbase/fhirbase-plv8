test = require('./helpers')
assert = require('assert')
sql = require('../src/new_honey.coffee')

tests = test.loadEdn(__dirname + '/honey_spec.edn')


describe "HONEY", ->
  tests.forEach ([k,v])->
    it "#{JSON.stringify(k)} => #{v[0]}", ->
      assert.deepEqual(sql(k), v)
