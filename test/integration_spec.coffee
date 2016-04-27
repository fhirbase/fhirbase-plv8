plv8 = require('../plpl/src/plv8')
assert = require('assert')

copy = (x)-> JSON.parse(JSON.stringify(x))

describe 'Integration',->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'conformance', ->
    plv8.execute(
      'SELECT fhir_create_storage($1)',
      [JSON.stringify(resourceType: 'Order')]
    )
    conformance = plv8.execute(
      'SELECT fhir_conformance($1)',
      [JSON.stringify({somekey: 'somevalue'})]
    )
    assert.equal(
      JSON.parse(conformance[0].fhir_conformance)
        .rest[0].resource.filter(
          (resource)-> resource.type == 'Order'
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
        [JSON.stringify(resourceType: 'Order')]
      )
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )

    it 'create', ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'order' AND table_schema = current_schema()
        ''').length,
        1
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'order_history' AND table_schema = current_schema()
        ''').length,
        1
      )

    it 'create all', ->
      this.timeout(15000) # creating all storage takes longer time than default 2000 milliseconds <https://mochajs.org/#timeouts>
      plv8.execute('SELECT fhir_create_all_storages()')
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'order' AND table_schema = current_schema()
        ''').length,
        1
      )

    it 'drop', ->
      plv8.execute(
        'SELECT fhir_drop_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'order' AND table_schema = current_schema()
        ''').length,
        0
      )
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'order_history' AND table_schema = current_schema()
        ''').length,
        0
      )

    it 'drop all', ->
      plv8.execute('SELECT fhir_drop_all_storages()')
      assert.equal(
        plv8.execute('''
          SELECT * from information_schema.tables
          WHERE table_name = 'order' AND table_schema = current_schema()
        ''').length,
        0
      )

    it 'truncate', ->
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {resourceType: 'Order'})]
      )
      truncateOutcome =
        plv8.execute(
          'SELECT fhir_truncate_storage($1)',
          [JSON.stringify(resourceType: 'Order')]
        )
      issue = JSON.parse(truncateOutcome[0].fhir_truncate_storage).issue[0]
      assert.equal(issue.diagnostics, 'Resource type "Order" has been truncated')

    it 'describe', ->
      describe = plv8.execute(
        'SELECT fhir_describe_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )
      assert.equal(
        JSON.parse(describe[0].fhir_describe_storage).name,
        'order'
      )

  describe 'CRUD', ->
    before ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )

    beforeEach ->
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )

    it 'create', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {
              resourceType: 'Order', name: 'foo bar'
            })]
          )[0].fhir_create_resource
        )
      assert.equal(created.name, 'foo bar')

    it 'read', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {resourceType: 'Order'})]
          )[0].fhir_create_resource
        )
      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Order')]
          )[0].fhir_read_resource
        )
      assert.equal(readed.id, created.id)

    it 'vread', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {resourceType: 'Order'})]
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
            [JSON.stringify(resource: {resourceType: 'Order', name: 'foo'})]
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
              id: 'toBeDeleted', resourceType: 'Order'
            })]
          )[0].fhir_create_resource
        )
      plv8.execute(
        'SELECT fhir_delete_resource($1)',
        [JSON.stringify(id: created.id, resourceType: 'Order')]
      )
      readDeleted =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Order')]
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
              id: 'toBeTerminated', resourceType: 'Order'
            })]
          )[0].fhir_create_resource
        )
      plv8.execute(
        'SELECT fhir_terminate_resource($1)',
        [JSON.stringify(resourceType: 'Order', id: created.id)]
      )
      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Order')]
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
            [JSON.stringify(resource: {resourceType: 'Order', name: 'foo'})]
          )[0].fhir_create_resource
        )

      patched =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_patch_resource($1)', [JSON.stringify(
              resource: {id: created.id, resourceType: 'Order'},
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
            [JSON.stringify(id: created.id, resourceType: 'Order')]
          )[0].fhir_resource_history
        )
      assert.deepEqual(read_patched.name, 'bar2')
      assert.equal(hx.total, 2)
      assert.equal(hx.entry.length, 2)

  describe 'History', ->
    before ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )

    beforeEach ->
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )

    it 'resource', ->
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {
              resourceType: 'Order', name: 'foo'
            })]
          )[0].fhir_create_resource
        )
      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Order')]
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
            [JSON.stringify(id: readed.id, resourceType: 'Order')]
          )[0].fhir_delete_resource
        )
      hx =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_resource_history($1)',
            [JSON.stringify(id: readed.id, resourceType: 'Order')]
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
        [JSON.stringify(resource: {resourceType: 'Order', name: 'u1'})]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {resourceType: 'Order', name: 'u2'})]
      )
      created =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_create_resource($1)',
            [JSON.stringify(resource: {
              resourceType: 'Order', name: 'foo'
            })]
          )[0].fhir_create_resource
        )

      readed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_read_resource($1)',
            [JSON.stringify(id: created.id, resourceType: 'Order')]
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
            [JSON.stringify(id: readed.id, resourceType: 'Order')]
          )[0].fhir_delete_resource
        )
      hx =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_resource_type_history($1)',
            [JSON.stringify(resourceType: 'Order')]
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
        [JSON.stringify(resourceType: 'Order')]
      )
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )

    beforeEach ->
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Order')]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {
          resourceType: 'Order',
          identifier: {
            system: 'http://example.com/OrderIdentifier',
            value: 'foo'
          }
        })]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(resource: {
          resourceType: 'Order',
          identifier: {
            system: 'http://example.com/OrderIdentifier',
            value: 'bar'
          }
        })]
      )

    describe 'search by', ->
      it 'identifier', ->
        searched =
          JSON.parse(
            plv8.execute(
              'SELECT fhir_search($1)',
              [JSON.stringify(
                resourceType: 'Order',
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
            [JSON.stringify(resourceType: 'Order', name: 'identifier')]
          )[0].fhir_index_parameter
        )
      assert.equal(indexed[0].status, 'ok')
      assert.equal(indexed[0].message, 'Index order_identifier_token was created')

    it 'analyze', ->
      analyzed =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_analyze_storage($1)',
            [JSON.stringify(resourceType: 'Order')]
          )[0].fhir_analyze_storage
        )
      assert.equal(analyzed.message, 'analyzed')

    it 'explain', ->
      explained =
        plv8.execute(
          'SELECT fhir_explain_search($1)',
          [JSON.stringify(
            resourceType: 'Order',
            queryString: 'identifier=foo'
          )]
        )[0].fhir_explain_search

      assert.equal(explained, 1)

  describe 'Transaction', ->
    before ->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: 'Patient')]
      )

    beforeEach ->
      plv8.execute(
        'SELECT fhir_truncate_storage($1)',
        [JSON.stringify(resourceType: 'Patient')]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(
          allowId: true,
          resource: {id: 'patient-to-delete-id', resourceType: 'Patient'}
        )]
      )
      plv8.execute(
        'SELECT fhir_create_resource($1)',
        [JSON.stringify(
          allowId: true,
          resource: {
            id: 'patient-to-update-id',
            resourceType: 'Patient',
            name: [{given: ['Name to update']}]
          }
        )]
      )

    it 'seed data should be', ->
      assert.equal(
        JSON.parse(
          plv8.execute(
            'SELECT fhir_search($1)',
            [JSON.stringify(
              resourceType: 'Patient',
              queryString: '_id=patient-to-delete-id'
            )]
          )[0].fhir_search
        ).total,
        1
      )
      assert.equal(
        JSON.parse(
          plv8.execute(
            'SELECT fhir_search($1)',
            [JSON.stringify(
              resourceType: 'Patient',
              queryString: '_id=patient-to-update-id&name=Name to update'
            )]
          )[0].fhir_search
        ).total,
        1
      )

    it 'should processed in order (DELETE, POST, PUT, GET)', ->
      bundle =
        resourceType: 'Bundle'
        id: 'bundle-transaction-id'
        type: 'transaction'
        entry: [
          # GET (read) should processed last <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            request:
              method: 'GET'
              url: '/Patient/patient-to-delete-id'
          }
          # GET (search) also should processed last <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            request:
              method: 'GET'
              url: '/Patient?name=Name to create'
          }
          # PUT (update) should processed after POST (create) <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            resource:
              resourceType: 'Patient'
              active: true
              name: [{family: ['Name to update updated']}]
            request:
              method: 'PUT'
              url: '/Patient/patient-to-update-id'
          }
          # POST (create) should processed after DELETE <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            resource:
              resourceType: 'Patient'
              name: [{family: ['Name to create']}]
            request:
              method: 'POST'
              url: '/Patient'
          }
          # DELETE should processed first <http://hl7-fhir.github.io/http.html#2.1.0.16.2>
          {
            request:
               method: 'DELETE'
               url: '/Patient/patient-to-delete-id'
          }
        ]

      transaction =
        JSON.parse(
          plv8.execute(
            'SELECT fhir_transaction($1)',
            [JSON.stringify(bundle)]
          )[0].fhir_transaction
        )

      assert.equal(transaction.resourceType, 'Bundle')
      assert.equal(transaction.type, 'transaction-response')

      assert.equal(transaction.entry[0].resourceType, 'Patient')
      assert.equal(transaction.entry[0].meta.extension[0].url, 'fhir-request-method')
      assert.equal(transaction.entry[0].meta.extension[0].valueString, 'DELETE')
      assert.equal(transaction.entry[0].id, 'patient-to-delete-id')

      assert.equal(transaction.entry[1].resourceType, 'Patient')
      assert.equal(transaction.entry[1].meta.extension[0].url, 'fhir-request-method')
      assert.equal(transaction.entry[1].meta.extension[0].valueString, 'POST')
      assert.equal(transaction.entry[1].name[0].family[0], 'Name to create')

      assert.equal(transaction.entry[2].resourceType, 'Patient')
      assert.equal(transaction.entry[2].meta.extension[0].url, 'fhir-request-method')
      assert.equal(transaction.entry[2].meta.extension[0].valueString, 'PUT')
      assert.equal(transaction.entry[2].id, 'patient-to-update-id')
      assert.equal(transaction.entry[2].name[0].family[0], 'Name to update updated')

      assert.equal(transaction.entry[3].resourceType, 'OperationOutcome')
      assert.equal(transaction.entry[3].issue[0].code, 'not-found')
      assert.equal(transaction.entry[3].issue[0].details.coding[0].display, 'The resource "patient-to-delete-id" has been deleted')

      assert.equal(transaction.entry[4].resourceType, 'Bundle')
      assert.equal(transaction.entry[4].type, 'searchset')
      assert.equal(transaction.entry[4].total, 1)
      assert.equal(transaction.entry[4].entry[0].resource.resourceType, 'Patient')
      assert.equal(transaction.entry[4].entry[0].resource.name[0].family[0], 'Name to create')
