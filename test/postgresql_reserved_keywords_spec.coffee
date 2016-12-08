conformance = require('../src/fhir/conformance')
crud = require('../src/fhir/crud')
history = require('../src/fhir/history')
pg_meta = require('../src/core/pg_meta')
plv8 = require('../plpl/src/plv8')
schema = require('../src/core/schema')
search = require('../src/fhir/search')

assert = require('assert')

copy = (x)-> JSON.parse(JSON.stringify(x))

# PostgreSQL reserved key words
# <https://github.com/fhirbase/fhirbase-plv8/issues/77>,
# <https://github.com/fhirbase/fhirbase-plv8/issues/88>,
# <http://www.postgresql.org/docs/current/static/sql-keywords-appendix.html#KEYWORDS-TABLE>.

describe 'PostgreSQL reserved key words', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  describe 'Conformance', ->
    it 'should respect Task', ->
      schema.fhir_create_storage(plv8, resourceType: 'Task')
      assert.equal(
        conformance.fhir_conformance(plv8, {somekey: 'somevalue'})
          .rest[0].resource.filter(
            (resource)-> resource.type == 'Task'
          ).length,
        1
      )

  describe 'Schema storage', ->
    it 'create', ->
      schema.fhir_create_storage(plv8, resourceType: 'Task')
      assert.equal(pg_meta.table_exists(plv8, 'task'), true)
      assert.equal(pg_meta.table_exists(plv8, 'task_history'), true)

    it 'drop', ->
      schema.fhir_drop_storage(plv8, resourceType: 'Task')
      assert.equal(pg_meta.table_exists(plv8, 'task'), false)
      assert.equal(pg_meta.table_exists(plv8, 'task_history'), false)

    it 'truncate', ->
      schema.fhir_create_storage(plv8, resourceType: 'Task')
      crud.fhir_create_resource(plv8, resource: {resourceType: 'Task'})
      truncateOutcome = schema.fhir_truncate_storage(plv8, resourceType: 'Task')
      issue = truncateOutcome.issue[0]
      assert.equal(issue.diagnostics, 'Resource type "Task" has been truncated')

    it 'describe', ()->
      schema.fhir_create_storage(plv8, resourceType: 'Task')
      assert.equal(
        schema.fhir_describe_storage(plv8, resourceType: 'Task').name,
        'task'
      )

  describe 'CRUD', ->
    before ->
      schema.fhir_create_storage(plv8, resourceType: 'Task')

    beforeEach ->
      schema.fhir_truncate_storage(plv8, resourceType: 'Task')

    it 'delete', ->
      created = crud.fhir_create_resource(plv8, allowId: true, resource: {
        id: 'toBeDeleted', resourceType: 'Task'
      })
      crud.fhir_delete_resource(plv8, {id: created.id, resourceType: 'Task'})
      readDeleted = crud.fhir_read_resource(plv8, {
        id: created.id, resourceType: 'Task'
      })
      assert.equal(readDeleted.resourceType, 'OperationOutcome')
      issue = readDeleted.issue[0]
      assert.equal(
        issue.details.coding[0].display,
        'The resource "toBeDeleted" has been deleted'
      )

    it 'create', ->
      created = crud.fhir_create_resource(plv8, resource: {
        resourceType: 'Task', name: 'foo bar'
      })
      assert.equal(created.name, 'foo bar')

    it 'read', ->
      created = crud.fhir_create_resource(plv8, resource: {resourceType: 'Task'})
      readed = crud.fhir_read_resource(plv8, {
        id: created.id, resourceType: 'Task'
      })
      assert.equal(readed.id, created.id)

    it 'vread', ->
      created = crud.fhir_create_resource(plv8, resource: {resourceType: 'Task'})
      created.versionId = created.meta.versionId
      vreaded = crud.fhir_vread_resource(plv8, created)
      assert.equal(created.id, vreaded.id)

    it 'update', ->
      created = crud.fhir_create_resource(plv8, resource: {
        resourceType: 'Task', name: 'foo'
      })
      to_update = copy(created)
      to_update.name = 'bar'

      updated = crud.fhir_update_resource(plv8, resource: to_update)
      assert.equal(updated.name, to_update.name)

    it 'terminate', ->
      created = crud.fhir_create_resource(plv8, allowId: true, resource: {
        id: 'toBeTerminated', resourceType: 'Task'
      })
      crud.fhir_terminate_resource(plv8, {resourceType: 'Task', id: created.id})
      readed = crud.fhir_read_resource(plv8, {
        id: created.id, resourceType: 'Task'
      })
      assert.equal(
        readed.issue[0].diagnostics,
        'Resource Id "toBeTerminated" does not exist')

  describe 'History', ->
    before ->
      schema.fhir_create_storage(plv8, resourceType: 'Task')

    beforeEach ->
      plv8.execute("SET plv8.start_proc = 'plv8_init'")
      schema.fhir_truncate_storage(plv8, resourceType: 'Task')

    it 'resource', ->
      created = crud.fhir_create_resource(plv8, resource: {
        resourceType: 'Task', name: 'foo'
      })
      readed = crud.fhir_read_resource(plv8, {id: created.id, resourceType: 'Task'})
      toUpdate = copy(readed)
      toUpdate.name = 'bar'

      crud.fhir_update_resource(plv8, resource: toUpdate)

      deleted = crud.fhir_delete_resource(plv8, {
        id: readed.id, resourceType: 'Task'
      })

      hx = history.fhir_resource_history(plv8, {
        id: readed.id, resourceType: 'Task'
      })
      assert.equal(hx.total, 3)
      assert.equal(hx.entry.length, 3)
      assert.deepEqual(
        hx.entry.map((entry) -> entry.request.method),
        ['DELETE', 'PUT', 'POST']
      )

    it 'resource type', ->
      schema.fhir_truncate_storage(plv8, resourceType: 'Task')
      crud.fhir_create_resource(plv8, resource: {resourceType: 'Task', name: 'u1'})
      crud.fhir_create_resource(plv8, resource: {resourceType: 'Task', name: 'u2'})
      created = crud.fhir_create_resource(plv8, resource: {
        resourceType: 'Task', name: 'foo'
      })

      readed = crud.fhir_read_resource(plv8, {
        id: created.id, resourceType: 'Task'
      })
      toUpdate = copy(readed)
      toUpdate.name = 'bar'

      crud.fhir_update_resource(plv8, resource: toUpdate)

      deleted = crud.fhir_delete_resource(plv8, {
        id: readed.id, resourceType: 'Task'
      })

      hx = history.fhir_resource_type_history(plv8, resourceType: 'Task')
      assert.equal(hx.total, 5)

      assert.deepEqual(
        hx.entry.map((entry) -> entry.request.method),
        ['DELETE', 'PUT', 'POST', 'POST', 'POST']
      )

  describe 'Search API', ->
    before ->
      schema.fhir_drop_storage(plv8, resourceType: 'Task')
      schema.fhir_create_storage(plv8, resourceType: 'Task')

    beforeEach ->
      schema.fhir_truncate_storage(plv8, resourceType: 'Task')
      crud.fhir_create_resource(plv8, resource: {
        resourceType: 'Task',
        identifier: {
          system: 'http://example.com/TaskIdentifier',
          value: 'foo'
        }
      })
      crud.fhir_create_resource(plv8, resource: {
        resourceType: 'Task',
        identifier: {
          system: 'http://example.com/TaskIdentifier',
          value: 'bar'
        }
      })

    describe 'search by', ->
      it 'identifier', ->
        assert.equal(
          search.fhir_search(plv8,
            resourceType: 'Task', queryString: 'identifier=foo').total,
          1)

    it 'index', ->
      indexed = search.fhir_index_parameter(plv8,
        resourceType: 'Task', name: 'identifier')
      assert.equal(indexed[0].status, 'ok')
      assert.equal(indexed[0].message, 'Index task_identifier_token was created')

    it 'analyze', ->
      assert.equal(
        search.fhir_analyze_storage(plv8, resourceType: 'Task').message,
        'analyzed'
      )

    it 'explain', ->
      explain = search.fhir_explain_search(plv8, {
        queryString: 'identifier=foo', resourceType: 'Task'
      })

      assert.equal(
        JSON.parse(explain[0]['QUERY PLAN'])[0].Plan.Plans[0]['Relation Name'],
        'task'
      )
