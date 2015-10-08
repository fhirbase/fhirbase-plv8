sql = require('../src/honey')
test = require('./helpers')
assert = require('assert')

tests = test.loadYaml(__dirname + '/honey_spec.yaml')


strcmp = (x,y)->
  return unless x and y
  x.split('').forEach (l,i)->
    if l != y[i]
      console.log(x.substring(0,i+2))
      console.log(y.substring(0,i+2), '^')

describe "honey", ()->
  tests.forEach (x)->
    it x.res, ()->
      res = sql(x.exp)
      strcmp(res[0],x.res[0])
      assert.deepEqual(res, x.res)
