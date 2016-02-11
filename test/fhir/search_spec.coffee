search = require('../../src/fhir/search')
schema = require('../../src/core/schema')
crud = require('../../src/fhir/crud')
honey = require('../../src/honey')
plv8 = require('../../plpl/src/plv8')
fs = require('fs')
test = require('../helpers.coffee')

assert = require('assert')

# plv8.debug = true
get_in = (obj, path)->
  cur = obj
  cur = cur[item] for item in path when cur
  cur

match = (x)-> (y)-> y.indexOf(x) > -1

# plv8.debug = true

# console.log plv8.execute("SET search_path='user1';")
# console.log plv8.execute("SHOW search_path;")

FILTER = 'uri'
FILTER = 'incl'
FILTER = 'search'

fs.readdirSync("#{__dirname}/search").filter(match(FILTER)).forEach (yml)->
  spec = test.loadYaml("#{__dirname}/search/#{yml}")
  describe spec.title, ->
    before ->
      plv8.execute("SET plv8.start_proc = 'plv8_init'")
      # plv8.debug = true

      for res in spec.resources
        schema.fhir_create_storage(plv8, resourceType: res)
        schema.fhir_truncate_storage(plv8, resourceType: res)

      for res in spec.fixtures
        crud.fhir_create_resource(plv8, allowId: true, resource: res)

      for idx in (spec.indices or [])
        search.fhir_unindex_parameter(plv8, idx)
        search.fhir_index_parameter(plv8, idx)

      for idx_ord in (spec.index_order or [])
        search.fhir_unindex_order(plv8, idx_ord.query)
        search.fhir_index_order(plv8, idx_ord.query)

      for res in spec.resources
        search.fhir_analyze_storage(plv8, resourceType: res)

    spec.queries.forEach (q)->
      it "#{JSON.stringify(q.query)}", ->

        plv8.execute "SET enable_seqscan = OFF;" if (q.indexed or q.indexed_order)

        res = search.fhir_search(plv8, q.query)
        # console.log(JSON.stringify(res))
        explain = JSON.stringify(search.fhir_explain_search(plv8, q.query))
        # console.log(JSON.stringify(search.fhir_search_sql(plv8, q.query)))

        plv8.execute "SET enable_seqscan = ON;" if (q.indexed or q.indexed_order)

        if q.total || q.total == 0
          assert.equal(res.total, q.total)

        (q.probes || []).forEach (probe)-> assert.equal(get_in(res, probe.path), probe.result)

        # console.log(explain)

        if q.indexed
          assert(explain.indexOf("Index Cond") > -1, "Should be indexed but #{explain}")
        if q.indexed_order
          assert((explain.indexOf("Index Scan") > -1) && (explain.indexOf("Scan Direction") > -1), "Should be indexed but #{explain}")

describe 'AuditEvent search', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    schema.fhir_drop_storage(plv8, resourceType: 'AuditEvent')
    schema.fhir_create_storage(plv8, resourceType: 'AuditEvent')
    search.fhir_index_parameter(plv8,
      resourceType: 'AuditEvent', name: 'desc', token: 'action')

  beforeEach ->
    schema.fhir_truncate_storage(plv8, resourceType: 'AuditEvent')
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'AuditEvent',
      object: {name: 'foo'}
    })
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'AuditEvent',
      object: {name: 'bar'},
      event: {action: 'xyz'}
    })

  it 'action', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'action=xyz').total,
      1)

  it 'desc', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'desc=foo').total,
      1)
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'desc=bar').total,
      1)
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'desc=muhaha').total,
      0)

  it 'desc and action', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'desc=foo,action=xyz').total,
      1)

describe 'Search normalize', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

    schema.fhir_create_storage(plv8, resourceType: 'Patient')
    schema.fhir_create_storage(plv8, resourceType: 'MedicationAdministration')

    search.fhir_index_parameter(plv8, resourceType: 'Patient', name: 'name')

  beforeEach ->
    schema.fhir_truncate_storage(plv8, resourceType: 'Patient')
    schema.fhir_truncate_storage(plv8, resourceType: 'MedicationAdministration')

    crud.fhir_create_resource(plv8, allowId: true, resource: {
      id: 'patient-id', resourceType: 'Patient', name: [{given: ['bar']}]
    })

    crud.fhir_create_resource(plv8, allowId: true, resource: {
      id: 'medication-administration-id',
      resourceType: 'MedicationAdministration',
      patient: {reference: 'Patient/patient-id'}
    })

  it 'by id', ->
    assert.equal(
      search.fhir_search(
        plv8,
        resourceType: 'MedicationAdministration',
        queryString: '_id=medication-administration-id'
      ).total,
      1)

  describe 'by reference', ->
    it 'as reference', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'MedicationAdministration',
          queryString: 'patient=Patient/patient-id'
        ).total,
        1)

    it 'as reference beginning with slash', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'MedicationAdministration',
          queryString: 'patient=/Patient/patient-id'
        ).total,
        1)

    it 'as reference beginning with slash with history', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'MedicationAdministration',
          queryString: 'patient=/Patient/patient-id/_history/patient-fake-history-id'
        ).total,
        1)

    it 'as URL', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'MedicationAdministration',
          queryString: 'patient=http://fhirbase/Patient/patient-id'
        ).total,
        1)

    it 'as URL with history', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'MedicationAdministration',
          queryString: 'patient=https://fhirbase/Patient/patient-id/_history/patient-fake-history-id'
        ).total,
        1)
