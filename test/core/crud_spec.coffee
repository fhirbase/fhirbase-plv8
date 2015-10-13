plv8 = require('../../plpl/src/plv8')
crud = require('../../src/core/crud')
schema = require('../../src/core/schema')

assert = require('assert')

copy = (x)-> JSON.parse(JSON.stringify(x))

describe "CORE: CRUD spec", ->
  beforeEach ->
    schema.drop_storage(plv8, 'Users')
    schema.create_storage(plv8, 'Users')

  it "create", ->
    created = crud.create(plv8, {resourceType: 'Users', name: 'admin'})
    assert.notEqual(created.id , false)
    assert.notEqual(created.meta.versionId, undefined)
    assert.equal(created.name, 'admin')


  it "read", ->
    created = crud.create(plv8, {resourceType: 'Users', name: 'admin'})
    read = crud.read(plv8, {id: created.id, resourceType: 'Users'})
    assert.equal(read.id, created.id)

    vread = crud.vread(plv8, read)
    assert.equal(read.id, vread.id)
    assert.equal(read.meta.versionId, vread.meta.versionId)

  it "update", ->
    created = crud.create(plv8, {resourceType: 'Users', name: 'admin'})
    read = crud.read(plv8, {id: created.id, resourceType: 'Users'})
    to_update = copy(read)
    to_update.name = 'changed'

    updated = crud.update(plv8, to_update)
    assert.equal(updated.name, to_update.name)
    assert.notEqual(updated.meta.versionId, false)
    assert.notEqual(updated.meta.versionId, read.meta.versionId)


    read_updated = crud.read(plv8, updated)
    assert.equal(read_updated.name, to_update.name)
    assert.equal(read_updated.meta.request.method, 'PUT')

    hx  = crud.history(plv8, {id: read.id, resourceType: 'Users'})
    assert.equal(hx.total, 2)
    assert.equal(hx.entry.length, 2)

  it "delete", ->
    created = crud.create(plv8, {resourceType: 'Users', name: 'admin'})
    read = crud.read(plv8, {id: created.id, resourceType: 'Users'})

    deleted = crud.delete(plv8, {id: read.id, resourceType: 'Users'})
    assert.equal(deleted.meta.request.method, 'DELETE')

    hx_deleted  = crud.history(plv8, {id: read.id, resourceType: 'Users'})
    assert.equal(hx_deleted.total, 2)
    assert.equal(hx_deleted.entry.length, 2)
