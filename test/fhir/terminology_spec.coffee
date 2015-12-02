term = require('../../src/fhir/terminology')
test = require('../helpers.coffee')
plv8 = require('../../plpl/src/plv8')

assert = require('assert')
log = (x)->
  console.log(JSON.stringify(x, null, " "))

expand = (q)-> term.fhir_expand_valueset(plv8, q)

describe "terminology", ->
  it "expand", ->
    res =  expand(id: "administrative-gender", filter: 'fe')
    assert.equal(res.length, 1)

    res =  expand(id: "administrative-gender")
    assert.equal(res.length, 4)
