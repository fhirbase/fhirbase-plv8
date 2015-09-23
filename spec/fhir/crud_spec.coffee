plv8 = require('../../plpl/src/plv8')
crud = require('../../src/fhir/crud')
schema = require('../../src/fhir/schema')

copy = (x)-> JSON.parse(JSON.stringify(x))

describe "CRUD", ()->
  beforeEach ()->
    schema.drop_table(plv8, 'Users')
    schema.create_table(plv8, 'Users')

  it "simple", ()->
    created = crud.create(plv8, {resourceType: 'Users', name: 'admin'})
    expect(created.id).not.toBeFalsy()
    expect(created.id).not.toBeFalsy()
    expect(created.meta.versionId).not.toBe(undefined)
    expect(created.name).toEqual('admin')

    read = crud.read(plv8, {id: created.id, resourceType: 'Users'})
    expect(read.id).toEqual(created.id)

    vread = crud.vread(plv8, read)
    expect(read.id).toEqual(vread.id)
    expect(read.meta.versionId).toEqual(vread.meta.versionId)

    to_update = copy(read)
    to_update.name = 'changed'

    updated = crud.update(plv8, to_update)
    expect(updated.name).toEqual(to_update.name)
    expect(updated.meta.versionId).not.toBeFalsy()
    expect(updated.meta.versionId).not.toEqual(read.meta.versionId)


    read_updated = crud.read(plv8, updated)
    expect(read_updated.name).toEqual(to_update.name)
    expect(read_updated.meta.request.method).toEqual('PUT')

    hx  = crud.history(plv8, {id: read.id, resourceType: 'Users'})
    expect(hx.total).toEqual(2)
    expect(hx.entry.length).toEqual(2)

    deleted = crud.delete(plv8, {id: read.id, resourceType: 'Users'})
    expect(deleted.meta.request.method).toEqual('DELETE')

    hx_deleted  = crud.history(plv8, {id: read.id, resourceType: 'Users'})
    expect(hx_deleted.total).toEqual(3)
    expect(hx_deleted.entry.length).toEqual(3)
