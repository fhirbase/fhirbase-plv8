plv8 = require('../../plpl/src/plv8')
crud = require('../../src/core/crud')
schema = require('../../src/core/schema')

assert = require('assert')

copy = (x)-> JSON.parse(JSON.stringify(x))

describe "CORE: CRUD spec", ->
  beforeEach ->
    schema.drop_storage(plv8, resourceType: 'Users')
    schema.create_storage(plv8, resourceType: 'Users')

  it "create", ->
    created = crud.create_resource(plv8, {resourceType: 'Users', name: 'admin'})
    assert.notEqual(created.id , false)
    assert.notEqual(created.meta.versionId, undefined)
    assert.equal(created.name, 'admin')


  it "read", ->
    created = crud.create_resource(plv8, {resourceType: 'Users', name: 'admin'})
    read = crud.read_resource(plv8, {id: created.id, resourceType: 'Users'})
    assert.equal(read.id, created.id)

    vread = crud.vread_resource(plv8, read)
    assert.equal(read.id, vread.id)
    assert.equal(read.meta.versionId, vread.meta.versionId)

  it "read unexisting", ->
    read = crud.read_resource(plv8, {id: 'unexisting', resourceType: 'Users'})
    assert.equal(read.resourceType, 'OperationOutcome')
    issue = read.issue[0]
    assert.equal(issue.severity, 'error')
    assert.equal(issue.code, 'not-found')


  it "update", ->
    created = crud.create_resource(plv8, {resourceType: 'Users', name: 'admin'})
    read = crud.read_resource(plv8, {id: created.id, resourceType: 'Users'})
    to_update = copy(read)
    to_update.name = 'changed'

    updated = crud.update_resource(plv8, to_update)
    assert.equal(updated.name, to_update.name)
    assert.notEqual(updated.meta.versionId, false)
    assert.notEqual(updated.meta.versionId, read.meta.versionId)


    read_updated = crud.read_resource(plv8, updated)
    assert.equal(read_updated.name, to_update.name)
    # assert.equal(read_updated.meta.request.method, 'PUT')

    hx  = crud.resource_history(plv8, {id: read.id, resourceType: 'Users'})
    assert.equal(hx.total, 2)
    assert.equal(hx.entry.length, 2)

    delete to_update.meta
    to_update.name = 'udpated without meta'

    updated = crud.update_resource(plv8, to_update)
    assert.equal(updated.name, to_update.name)
    assert.notEqual(updated.meta.versionId, false)
    assert.notEqual(updated.meta.versionId, read.meta.versionId)

  it "update unexisting", ->
    updated = crud.update_resource(plv8, {resourceType: "Users", id: "unexisting"})
    assert.equal(updated.resourceType, 'OperationOutcome')

  it "delete", ->
    created = crud.create_resource(plv8, {resourceType: 'Users', name: 'admin'})
    read = crud.read_resource(plv8, {id: created.id, resourceType: 'Users'})

    deleted = crud.delete_resource(plv8, {id: read.id, resourceType: 'Users'})
    # assert.equal(deleted.meta.request.method, 'DELETE')

    hx_deleted  = crud.resource_history(plv8, {id: read.id, resourceType: 'Users'})
    assert.equal(hx_deleted.total, 2)
    assert.equal(hx_deleted.entry.length, 2)

    read_deleted = crud.read_resource(plv8, {id: created.id, resourceType: 'Users'})
    assert.equal(read_deleted.resourceType, 'OperationOutcome')
    issue = read_deleted.issue[0]
    assert.equal(issue.severity, 'error')
    assert.equal(issue.code, 'not-found')

  it "history", ->
    created = crud.create_resource(plv8, {resourceType: 'Users', name: 'admin'})
    read = crud.read_resource(plv8, {id: created.id, resourceType: 'Users'})

    deleted = crud.delete_resource(plv8, {id: read.id, resourceType: 'Users'})
    # assert.equal(deleted.meta.request.method, 'DELETE')

    hx_deleted  = crud.resource_history(plv8, {id: read.id, resourceType: 'Users'})
    assert.equal(hx_deleted.total, 2)
    assert.equal(hx_deleted.entry.length, 2)

    read_deleted = crud.read_resource(plv8, {id: created.id, resourceType: 'Users'})
    assert.equal(read_deleted.resourceType, 'OperationOutcome')
    issue = read_deleted.issue[0]
    assert.equal(issue.severity, 'error')
    assert.equal(issue.code, 'not-found')

  it "parse_history_params", ->
    [res, errors] = crud.parse_history_params('_since=2010&_count=10')
    assert.deepEqual(res, {_since: '2010-01-01', _count: 10})

  it "resource type history", ->
    schema.truncate_storage(plv8, resourceType: 'Users')
    crud.create_resource(plv8, {resourceType: 'Users', name: 'u1'})
    crud.create_resource(plv8, {resourceType: 'Users', name: 'u2'})
    crud.create_resource(plv8, {resourceType: 'Users', name: 'u3'})

    res = crud.resource_type_history(plv8, resourceType: 'Users')
    assert.equal(res.total, 3)

    res = crud.resource_type_history(plv8, resourceType: 'Users', queryString: "_count=2&_since=2015-11")
    assert.equal(res.total, 2)
