plv8 = require('../plpl/src/plv8')
assert = require('assert')

copy = (x)-> JSON.parse(JSON.stringify(x))


describe 'Integration',->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'conformance', ->
    plv8.execute(
      'SELECT fhir_create_storage($1)',
      [JSON.stringify(resourceType: 'Task')]
    )
    conformance = plv8.execute(
      'SELECT fhir_conformance($1)',
      [JSON.stringify({somekey: 'somevalue'})]
    )
    assert.equal(
      JSON.parse(conformance[0].fhir_conformance)
        .rest[0].resource.filter(
          (resource)-> resource.type == 'Task'
        ).length,
      1
    )

  it 'FHIR version', ->
    version = plv8.execute("SELECT fhir_version()")[0].fhir_version
    assert.equal(
      !!version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )

  it 'Fhirbase version', ->
    version = plv8.execute("SELECT fhirbase_version()")[0].fhirbase_version
    assert.equal(
      !!version.match(/.*[0-9]*\.[0-9]*\.[0-9].*/),
      true
    )

  it 'Fhirbase release date', ->
    version = plv8.execute("SELECT fhirbase_release_date()")[0]
      .fhirbase_release_date

    assert.equal(
      !!version.match(/-?[0-9]{4}(-(0[1-9]|1[0-2])(-(0[0-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)?/),
      true
    )

  describe 'Schema storage', ->
    beforeEach ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )

    it 'create', ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'task' AND table_schema = current_schema()
        ''').length,
        1
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'task_history' AND table_schema = current_schema()
        ''').length,
        1
      )

    it 'create all', ->
      this.timeout(15000) # creating all storage takes longer time than default 2000 milliseconds <https://mochajs.org/#timeouts>
      plv8.execute('SELECT fhir_create_all_storages()')
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'task' AND table_schema = current_schema()
        ''').length,
        1
      )

    it 'drop', ->
      plv8.execute(
        'SELECT fhir_drop_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'task' AND table_schema = current_schema()
        ''').length,
        0
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'task_history' AND table_schema = current_schema()
        ''').length,
        0
      )

    it 'drop all', ->
      plv8.execute('SELECT fhir_drop_all_storages()')
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'task' AND table_schema = current_schema()
        ''').length,
        0
      )

    it 'truncate', ->
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {resourceType: 'Task'})]
      )
      truncateOutcome =
        plv8.execute(
          'SELECT fhir_truncate_storage($1)',
          [JSON.stringify(resourceType: 'Task')]
        )
      issue = JSON.parse(truncateOutcome[0].fhir_truncate_storage).issue[0]
      assert.equal(issue.diagnostics, 'Resource type "Task" has been truncated')

    it 'describe', ->
      describe = plv8.execute(
        'SELECT fhir_describe_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )
      assert.equal(
        JSON.parse(describe[0].fhir_describe_storage).name,
        'task'
      )

  describe 'CRUD', ->
    before ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )

    beforeEach ->
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )

    it 'create', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {
              resourceType: 'Task', name: 'foo bar'
            })]
          )[0].fhir_create_resource
        )
      assert.equal(created.name, 'foo bar')

    it 'read', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {resourceType: 'Task'})]
          )[0].fhir_create_resource
        )
      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Task')]
          )[0].fhir_read_resource
        )
      assert.equal(readed.id, created.id)

    it 'vread', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {resourceType: 'Task'})]
          )[0].fhir_create_resource
        )
      created.versionId = created.meta.versionId
      vreaded =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_vread_resource($1)',
            [JSON.stringify(created)]
          )[0].fhir_vread_resource
        )
      assert.equal(created.id, vreaded.id)

    it 'update', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {resourceType: 'Task', name: 'foo'})]
          )[0].fhir_create_resource
        )
      toUpdate = copy(created)
      toUpdate.name = 'bar'

      updated =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_update_resource($1)',
            [JSON.stringify(resource: toUpdate)]
          )[0].fhir_update_resource
        )
      assert.equal(updated.name, toUpdate.name)

    it 'delete', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(allowId: true, resource: {
              id: 'toBeDeleted', resourceType: 'Task'
            })]
          )[0].fhir_create_resource
        )
      plv8.execute(
        'SELECT fhir_delete_resource($1)',
        [JSON.stringify(id: created.id, resourceType: 'Task')]
      )
      readDeleted =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Task')]
          )[0].fhir_read_resource
        )
      assert.equal(readDeleted.resourceType, 'OperationOutcome')
      issue = readDeleted.issue[0]
      assert.equal(
        issue.details.coding[0].display,
        'The resource "toBeDeleted" has been deleted'
      )

    it 'terminate', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(allowId: true, resource: {
              id: 'toBeTerminated', resourceType: 'Task'
            })]
          )[0].fhir_create_resource
        )
      plv8.execute(
        'SELECT fhir_terminate_resource($1)',
        [JSON.stringify(resourceType: 'Task', id: created.id)]
      )
      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Task')]
          )[0].fhir_read_resource
        )
      assert.equal(
        readed.issue[0].diagnostics,
        'Resource Id "toBeTerminated" does not exist'
      )

    it 'patch', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {resourceType: 'Task', name: 'foo'})]
          )[0].fhir_create_resource
        )

      patched =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_patch_resource($1)', [JSON.stringify(
              resource: {id: created.id, resourceType: 'Task'},
              patch: [
                {op: 'replace', path: '/name', value: 'bar1'},
                {op: 'replace', path: '/name', value: 'bar2'}
              ]
          )])[0].fhir_patch_resource
        )

      assert.deepEqual(patched.name, 'bar2')
      assert.notEqual(patched.meta.versionId, false)
      assert.notEqual(patched.meta.versionId, created.meta.versionId)

      read_patched =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(patched)]
          )[0].fhir_read_resource
        )
      assert.deepEqual(read_patched.name, 'bar2')

      hx =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_resource_history($1)',
            [JSON.stringify(id: created.id, resourceType: 'Task')]
          )[0].fhir_resource_history
        )
      assert.deepEqual(read_patched.name, 'bar2')
      assert.equal(hx.total, 2)
      assert.equal(hx.entry.length, 2)

  describe 'History', ->
    before ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )

    beforeEach ->
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )

    it 'resource', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {
              resourceType: 'Task', name: 'foo'
            })]
          )[0].fhir_create_resource
        )
      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Task')]
          )[0].fhir_read_resource
        )
      toUpdate = copy(readed)
      toUpdate.name = 'bar'

      plv8.execute(
        'SELECT fhir_update_resource($1)',
        [JSON.stringify(resource: toUpdate)]
      )

      deleted =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_delete_resource($1)',
            [JSON.stringify(id: readed.id, resourceType: 'Task')]
          )[0].fhir_delete_resource
        )
      hx =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_resource_history($1)',
            [JSON.stringify(id: readed.id, resourceType: 'Task')]
          )[0].fhir_resource_history
        )

      assert.equal(hx.total, 3)
      assert.equal(hx.entry.length, 3)
      assert.deepEqual(
        hx.entry.map((entry) -> entry.request.method),
        ['DELETE', 'PUT', 'POST']
      )

    it 'resource type', ->
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {resourceType: 'Task', name: 'u1'})]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {resourceType: 'Task', name: 'u2'})]
      )
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {
              resourceType: 'Task', name: 'foo'
            })]
          )[0].fhir_create_resource
        )

      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Task')]
          )[0].fhir_read_resource
        )
      toUpdate = copy(readed)
      toUpdate.name = 'bar'

      plv8.execute(
        'SELECT fhir_update_resource($1)',
        [JSON.stringify(resource: toUpdate)]
      )

      deleted =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_delete_resource($1)',
            [JSON.stringify(id: readed.id, resourceType: 'Task')]
          )[0].fhir_delete_resource
        )
      hx =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_resource_type_history($1)',
            [JSON.stringify(resourceType: 'Task')]
          )[0].fhir_resource_type_history
        )

      assert.equal(hx.total, 5)

      assert.deepEqual(
        hx.entry.map((entry) -> entry.request.method),
        ['DELETE', 'PUT', 'POST', 'POST', 'POST']
      )

  describe 'Search API', ->
    before ->
      plv8.execute(
        'SELECT fhir_drop_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )

    beforeEach ->
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Task')]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {
          resourceType: 'Task',
          identifier: {
            system: 'http://example.com/TaskIdentifier',
            value: 'foo'
          }
        })]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {
          resourceType: 'Task',
          identifier: {
            system: 'http://example.com/TaskIdentifier',
            value: 'bar'
          }
        })]
      )

    it 'search by identifier', ->
      searched =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_search($1)',
            [JSON.stringify(
              resourceType: 'Task',
              queryString: 'identifier=foo'
            )]
          )[0].fhir_search
        )
      assert.equal(searched.total, 1)

    it 'index', ->
      indexed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_index_parameter($1)',
            [JSON.stringify(resourceType: 'Task', name: 'identifier')]
          )[0].fhir_index_parameter
        )
      assert.equal(indexed[0].status, 'ok')
      assert.equal(indexed[0].message, 'Index task_identifier_token was created')

    it 'analyze', ->
      analyzed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_analyze_storage($1)',
            [JSON.stringify(resourceType: 'Task')]
          )[0].fhir_analyze_storage
        )
      assert.equal(analyzed.message, 'analyzed')

    it 'explain', ->
      explained =
        plv8.execute(
          'SELECT fhir_explain_search($1)',
          [JSON.stringify(
            resourceType: 'Task',
            queryString: 'identifier=foo'
          )]
        )[0].fhir_explain_search

      assert.equal(explained, 1)

    it 'pagination', ->
      plv8.execute('''
        SELECT fhir_create_storage('{"resourceType": "Patient"}');
      ''')

      plv8.execute('''
        SELECT fhir_truncate_storage('{"resourceType": "Patient"}');
      ''')

      for _ in [1..11]
        plv8.execute('''
          SELECT fhir_create_resource(' {"resource": {"resourceType": "Patient"}} ');
        ''')

      outcome1 =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_search('
              {"resourceType": "Patient", "queryString": ""}
            ');
          ''')[0].fhir_search
        )
      assert.equal(outcome1.entry.length, 10)

      outcome2 =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_search('
              {"resourceType": "Patient", "queryString": "_count=3"}
            ');
          ''')[0].fhir_search
        )
      assert.equal(outcome2.entry.length, 3)

      outcome3 =
        JSON.parse(
          plv8.execute('''
            SELECT fhir_search('
              {"resourceType": "Patient", "queryString": "_count=999"}
            ');
          ''')[0].fhir_search
        )
      assert.equal(outcome3.entry.length, 11)
