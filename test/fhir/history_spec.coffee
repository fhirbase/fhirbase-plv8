plv8 = require('../../plpl/src/plv8')
crud = require('../../src/fhir/crud')
history = require('../../src/fhir/history')
schema = require('../../src/core/schema')

assert = require('assert')

copy = (x)-> JSON.parse(JSON.stringify(x))

describe 'CORE: History spec', ->
  before ->
    schema.fhir_create_storage(plv8, resourceType: 'Users')
    schema.fhir_create_storage(plv8, resourceType: 'Patient')

  beforeEach ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    schema.fhir_truncate_storage(plv8, resourceType: 'Users')
    schema.fhir_truncate_storage(plv8, resourceType: 'Patient')

  it 'resource history', ->
    created = crud.fhir_create_resource(plv8, resource: {
      resourceType: 'Users', name: 'foo'
    })
    readed = crud.fhir_read_resource(plv8, {id: created.id, resourceType: 'Users'})
    toUpdate = copy(readed)
    toUpdate.name = 'bar'

    crud.fhir_update_resource(plv8, resource: toUpdate)

    deleted = crud.fhir_delete_resource(plv8, {
      id: readed.id, resourceType: 'Users'
    })

    hx = history.fhir_resource_history(plv8, {
      id: readed.id, resourceType: 'Users'
    })
    assert.equal(hx.total, 3)
    assert.equal(hx.entry.length, 3)
    assert.deepEqual(
      hx.entry.map((entry) -> entry.request.method),
      ['DELETE', 'PUT', 'POST']
    )

  it 'resource history with _count', ->
    created = crud.fhir_create_resource(plv8, resource:  {resourceType: 'Users'})
    readed = crud.fhir_read_resource(plv8, {
      id: created.id, resourceType: 'Users'
    })
    crud.fhir_update_resource(plv8, resource: copy(readed))

    fullHistory = history.fhir_resource_history(plv8, {
      id: readed.id, resourceType: 'Users'
    })
    assert.equal(fullHistory.total, 2)
    assert.equal(fullHistory.entry.length, 2)

    limitedHistory = history.fhir_resource_history(plv8, {
      id: readed.id,
      resourceType: 'Users',
      queryString: '_count=1'
    })
    assert.equal(limitedHistory.total, 1)
    assert.equal(limitedHistory.entry.length, 1)

  it 'instance history with _since', ->
    for id in ['id1', 'id2']
      crud.fhir_create_resource(plv8, allowId: true, resource: {
        resourceType: 'Patient',
        id: id,
        name: [{family: [id + 'First']}]})
      crud.fhir_update_resource(plv8, resource: {
        resourceType: 'Patient',
        id: id,
        name: [{family: [id + 'Second']}]})
      crud.fhir_update_resource(plv8, resource: {
        resourceType: 'Patient',
        id: id,
        name: [{family: [id + 'Third']}]})
    count = plv8.execute("select count(*) from patient")
    assert.equal(count[0].count, 2)
    sinceHistory = history.fhir_resource_history(plv8, {
      id: 'id1',
      resourceType: 'Patient',
      queryString: '_since=2015-07-15'
    })
    assert.equal(sinceHistory.total, 3)
    assert.equal(sinceHistory.entry.length, 3)
    for e in sinceHistory.entry
      assert(e.resource.id, 'id1')

  it 'resource history _since and _before', ->
    created = crud.fhir_create_resource(plv8, resource:  {resourceType: 'Users'})
    readed = crud.fhir_read_resource(plv8, {
      id: created.id, resourceType: 'Users'
    })
    crud.fhir_update_resource(plv8, resource: copy(readed))

    plv8.execute(
      "UPDATE users_history
         SET valid_from = '01-Jan-1970'::timestamp with time zone
         WHERE id = '#{readed.id}'"
    )

    crud.fhir_update_resource(plv8, resource: copy(readed))

    fullHistory = history.fhir_resource_history(plv8, {
      id: readed.id, resourceType: 'Users'
    })
    assert.equal(fullHistory.total, 3)
    assert.equal(fullHistory.entry.length, 3)

    historySince = history.fhir_resource_history(plv8, {
      id: readed.id,
      resourceType: 'Users',
      queryString: '_since=2016-01-01'
    })
    assert.equal(historySince.total, 1)
    assert.equal(historySince.entry.length, 1)

    historyBefore = history.fhir_resource_history(plv8, {
      id: readed.id,
      resourceType: 'Users',
      queryString: '_before=2016-01-01'
    })
    assert.equal(historyBefore.total, 2)
    assert.equal(historyBefore.entry.length, 2)

  it 'parse_history_params', ->
    [res, errors] = history.parse_history_params('_since=2010&_count=10')
    assert.deepEqual(res, {_since: '2010-01-01', _count: 10})

  it 'resource type history', ->
    schema.fhir_truncate_storage(plv8, resourceType: 'Users')
    crud.fhir_create_resource(plv8, resource: {resourceType: 'Users', name: 'u1'})
    crud.fhir_create_resource(plv8, resource: {resourceType: 'Users', name: 'u2'})
    created = crud.fhir_create_resource(plv8, resource: {
      resourceType: 'Users', name: 'foo'
    })

    readed = crud.fhir_read_resource(plv8, {
      id: created.id, resourceType: 'Users'
    })
    toUpdate = copy(readed)
    toUpdate.name = 'bar'

    crud.fhir_update_resource(plv8, resource: toUpdate)

    deleted = crud.fhir_delete_resource(plv8, {
      id: readed.id, resourceType: 'Users'
    })

    hx = history.fhir_resource_type_history(plv8, resourceType: 'Users')
    assert.equal(hx.total, 5)

    assert.deepEqual(
      hx.entry.map((entry) -> entry.request.method),
      ['DELETE', 'PUT', 'POST', 'POST', 'POST']
    )

    hx = history.fhir_resource_type_history(
      plv8,
      resourceType: 'Users',
      queryString: '_count=2'
    )
    assert.equal(hx.total, 2)

  it 'resource type history with _since and _before', ->
    crud.fhir_create_resource(plv8, resource: {resourceType: 'Users', name: 'u1'})
    crud.fhir_create_resource(plv8, resource: {resourceType: 'Users', name: 'u2'})

    plv8.execute(
      "UPDATE users_history
       SET valid_from = '01-Jan-1970'::timestamp with time zone"
    )

    crud.fhir_create_resource(plv8, resource: {resourceType: 'Users', name: 'u3'})

    fullHistory = history.fhir_resource_type_history(plv8, {
      resourceType: 'Users'
    })
    assert.equal(fullHistory.total, 3)
    assert.equal(fullHistory.entry.length, 3)

    historySince = history.fhir_resource_type_history(plv8, {
      resourceType: 'Users',
      queryString: '_since=2016-01-01'
    })
    assert.equal(historySince.total, 1)
    assert.equal(historySince.entry.length, 1)

    historyBefore = history.fhir_resource_type_history(plv8, {
      resourceType: 'Users',
      queryString: '_before=2016-01-01'
    })
    assert.equal(historyBefore.total, 2)
    assert.equal(historyBefore.entry.length, 2)
