plv8 = require('../../plpl/src/plv8')
schema = require('../../src/core/schema')
pg_meta = require('../../src/core/pg_meta')
crud = require('../../src/fhir/crud')
assert = require('assert')


describe "CORE: schema", ()->
  it "drop Users storage", ()->
    schema.fhir_drop_storage(plv8, resourceType: 'Users')
    assert.equal(pg_meta.table_exists(plv8, 'users'), false)
    assert.equal(pg_meta.table_exists(plv8, 'users_history'), false)

  it "create Users storage and history.users", ()->
    schema.fhir_create_storage(plv8, resourceType: 'Users')
    assert.equal(pg_meta.table_exists(plv8, 'users'), true)
    assert.equal(pg_meta.table_exists(plv8, 'users_history'), true)

  it "change Users storage name", ()->
    desc = schema.fhir_describe_storage(plv8, resourceType: 'users')
    assert.equal(desc.name, 'users')

  it 'describe storage with PostgreSQL reserved name', ()->
    desc = schema.fhir_describe_storage(plv8, resourceType: 'Group')
    assert.equal(desc.name, 'group')

  it 'return error on create existing Users storage', ()->
    schema.fhir_create_storage(plv8, resourceType: 'Users')
    createOutcome = schema.fhir_create_storage(plv8, resourceType: 'Users')
    assert.equal(createOutcome.status, 'error')
    assert.equal(createOutcome.message, 'Table users already exists')

  it 'truncate Users storage', ()->
    schema.fhir_create_storage(plv8, resourceType: 'Users')
    crud.fhir_create_resource(
      plv8,
      resource: {resourceType: 'Users', name: 'John Doe'}
    )
    truncateOutcome = schema.fhir_truncate_storage(plv8, resourceType: 'Users')
    issue = truncateOutcome.issue[0]
    assert.equal(issue.severity, 'information')
    assert.equal(issue.code, 'informational')
    assert.equal(issue.details.coding[0].code, 'MSG_DELETED_DONE')
    assert.equal(issue.details.coding[0].display, 'Resource deleted')
    assert.equal(issue.diagnostics, 'Resource type "Users" has been truncated')

  it 'truncate unexisting storage', ()->
    schema.fhir_drop_storage(plv8, resourceType: 'Users')

    truncateOutcome = schema.fhir_truncate_storage(plv8, resourceType: 'Users')
    issue = truncateOutcome.issue[0]
    assert.equal(issue.severity, 'error')
    assert.equal(issue.code, 'not-found')
    assert.equal(issue.details.coding[0].code, 'MSG_UNKNOWN_TYPE')
    assert.equal(
      issue.details.coding[0].display,
      'Resource Type "Users" not recognised'
    )
    assert.equal(
      issue.diagnostics,
      "Resource Type \"Users\" not recognised." +
        " Try create \"Users\" resource:" +
        " `SELECT fhir_create_storage('{\"resourceType\": \"Users\"}');`"
      'Resource Id "unexistingId" with versionId "unexistingVersionId" does not exist'
    )

  it 'drop all storages', ->
    schema.fhir_create_storage(plv8, resourceType: 'Patient')
    assert.equal(pg_meta.table_exists(plv8, 'patient'), true)
    schema.fhir_drop_all_storages(plv8)
    assert.equal(pg_meta.table_exists(plv8, 'patient'), false)

  it 'create all storages', ->
    this.timeout(60000) # creating all storage takes longer time than default 2000 milliseconds <https://mochajs.org/#timeouts>
    schema.fhir_drop_all_storages(plv8)
    assert.equal(pg_meta.table_exists(plv8, 'patient'), false)
    schema.fhir_create_all_storages(plv8)
    assert.equal(pg_meta.table_exists(plv8, 'patient'), true)
