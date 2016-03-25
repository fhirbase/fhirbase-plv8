term = require('../../src/fhir/terminology')
crud = require('../../src/fhir/crud')
schema = require('../../src/core/schema')
test = require('../helpers.coffee')
plv8 = require('../../plpl/src/plv8')

assert = require('assert')
log = (x)-> console.log(JSON.stringify(x, null, " "))

expand = (q)-> term.fhir_expand_valueset(plv8, q)

TEST_CS = {
  id: 'mytestvs'
  url: '/mycodesystem'
  resourceType: 'CodeSystem'
  concept: [
    {
      code: 'b'
      display: 'b'
      concept: [{code: 'b1', display: 'b1'}]
    }
  ]
}

TEST_VS = {
  id: 'mytestvs'
  resourceType: 'ValueSet'
  codeSystem:
    system: 'mysystem1'
    concept: [
      {
        code: 'a1'
        display: 'A1'
        concept: [{code: 'nested', display: 'display'}]
      }
    ]
  compose:
    include: [
      {
        system: 'mysystem2'
        concept: [
         {code: 'a21', display: 'A21'}
         {code: 'a22', display: 'A22'}]
      }
      {
        system: 'mysystem2'
        concept: [
         {code: 'a31', display: 'A31'}
         {code: 'a32', display: 'A32'}]
      }
      {system: '/mycodesystem'}
    ]
}


big_valueset = require('./fixtures/valueset-ucum-common.json')
big_valueset.id = 'bigone'

describe "terminology", ->
  @timeout(50000)

  before (done)->
    schema.fhir_create_storage(plv8, {resourceType: 'CodeSystem'})
    crud.fhir_terminate_resource(plv8, {resourceType: 'ValueSet', id: TEST_VS.id})
    crud.fhir_terminate_resource(plv8, {resourceType: 'ValueSet', id: big_valueset.id})
    crud.fhir_terminate_resource(plv8, {resourceType: 'CodeSystem', id: TEST_CS.id})
    crud.fhir_create_resource(plv8, {resourceType: 'CodeSystem', allowId: true, resource: TEST_CS})
    crud.fhir_create_resource(plv8, {resourceType: 'ValueSet', allowId: true, resource: TEST_VS})
    done()

  it "expand", ->
    vs =  expand(id: "administrative-gender")
    res = vs.expansion.contains
    assert.equal(res.length, 4)

    vs =  expand(id: "administrative-gender", filter: 'fe')
    res = vs.expansion.contains
    assert.equal(res.length, 1)

  it "custom vs", ->
    vs =  expand(id: "mytestvs")
    res = vs.expansion.contains.map((x)-> x.code).sort()
    assert.deepEqual([ 'a1', 'a21', 'a22', 'a31', 'a32', 'b', 'b1', 'nested' ], res)

    vs =  expand(id: "mytestvs", filter: '32')
    res = vs.expansion.contains
    assert.equal(res.length, 1)

    vs =  expand(id: "mytestvs", filter: 'nested')
    res = vs.expansion.contains
    assert.equal(res.length, 1)

    vs =  expand(id: "mytestvs", filter: 'display')
    res = vs.expansion.contains
    assert.equal(res.length, 1)

    vs =  expand(id: "mytestvs", filter: 'b1')
    res = vs.expansion.contains
    console.log(res)
    assert.equal(res.length, 1)

    crud.fhir_update_resource plv8,
      resource:
        resourceType: 'ValueSet'
        id: TEST_VS.id
        codeSystem:
          system: 'updated'
          concept: [{code: 'updated', display: 'updated'}]

    vs =  expand(id: "mytestvs")
    assert.equal(vs.expansion.contains.length, 1)

    vs =  expand(id: "mytestvs", filter: 'display')
    assert.equal(vs.expansion.contains.length, 0)

    vs =  expand(id: "mytestvs", filter: 'updated')
    assert.equal(vs.expansion.contains.length, 1)

    crud.fhir_delete_resource(plv8, {resourceType: 'ValueSet', id: TEST_VS.id})

    res = expand(id: "mytestvs")
    assert.equal(res.resourceType, 'OperationOutcome')

  # 17 seconds
  # 0.5
  it "big valueset", ->
    crud.fhir_create_resource(plv8, {resourceType: 'ValueSet', allowId: true, resource: big_valueset})
    vs =  expand(id: big_valueset.id, filter: 'rem')
    assert(vs.expansion.contains[0].code.match(/rem/i), 'should contain rem')
