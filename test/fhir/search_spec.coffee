search = require('../../src/fhir/search')
schema = require('../../src/core/schema')
crud = require('../../src/core/crud')
honey = require('../../src/honey')
plv8 = require('../../plpl/src/plv8')

assert = require('assert')

# plv8.debug = true

describe "simple", ()->
  it "test", ()->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    schema.create_storage(plv8, 'patient')
    schema.truncate_storage(plv8, 'patient')

    crud.create(plv8, {resourceType: 'Patient', name: [{given: ['nicola']}]})
    crud.create(plv8, {resourceType: 'Patient', name: [{given: ['noise1']}]})
    crud.create(plv8, {resourceType: 'Patient', name: [{given: ['noise2']}]})
    crud.create(plv8, {resourceType: 'Patient', name: [{given: ['ivan']}]})
    crud.create(plv8, {resourceType: 'Patient', name: [{given: ['Avraam']}, {given: ['Lincoln']}]})


    res = search.search(plv8, {resourceType: 'Patient', queryString: 'name=nicola'})
    assert.equal(res.total, 1)
    assert.equal(res.entry.length, 1)
    assert.equal(res.entry[0].resource.name[0].given[0], 'nicola')

    res = search.search(plv8, {resourceType: 'Patient', queryString: 'name=noise'})
    assert.equal(res.total, 2)
    assert.equal(res.entry.length, 2)

    res = search.search(plv8, {resourceType: 'Patient', queryString: 'name=nicola,ivan'})
    assert.equal(res.total, 2)
    assert.equal(res.entry.length, 2)

    res = search.search(plv8, {resourceType: 'Patient', queryString: 'name=lincol'})
    assert.equal(res.total, 1)
    assert.equal(res.entry.length, 1)
    assert.equal(res.entry[0].resource.name[0].given[0], 'Avraam')
