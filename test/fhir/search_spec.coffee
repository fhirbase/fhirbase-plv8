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
        console.log("INDEX", idx);
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
          if q.total == "_undefined"
            assert.equal(res.total, undefined)
          else
            assert.equal(res.total, q.total)

        (q.probes || []).forEach (probe)->
          if probe.result == "_undefined"
            assert.equal(get_in(res, probe.path), undefined)
          else
            assert.equal(get_in(res, probe.path), probe.result)

        # console.log(explain)

        if q.indexed
          assert(explain.indexOf("Index Cond") > -1, "Should be indexed but #{explain}")
        if q.indexed_order
          assert((explain.indexOf("Index Scan") > -1) && (explain.indexOf("Scan Direction") > -1), "Should be indexed but #{explain}")

describe 'Search', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'by nonexistent resource storge should return outcome', -> #<https://github.com/fhirbase/fhirbase-plv8/issues/95>
    schema.fhir_drop_storage(plv8, resourceType: 'Patient')
    outcome = search.fhir_search(plv8,
      resourceType: 'Patient', queryString: 'name=foobar'
    )
    assert.equal(outcome.resourceType, 'OperationOutcome')
    assert.equal(outcome.issue[0].code, 'not-found')
    assert.equal(outcome.issue[0].details.coding[0].code, 'MSG_UNKNOWN_TYPE')
    assert.equal(
      outcome.issue[0].details.coding[0].display,
      'Resource Type "Patient" not recognised'
    )

describe 'AuditEvent search', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    schema.fhir_drop_storage(plv8, resourceType: 'AuditEvent')
    schema.fhir_create_storage(plv8, resourceType: 'AuditEvent')
    search.fhir_index_parameter(plv8,
      resourceType: 'AuditEvent', name: 'action')

  beforeEach ->
    schema.fhir_truncate_storage(plv8, resourceType: 'AuditEvent')
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'AuditEvent',
      entity: {name: 'foo'}
    })
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'AuditEvent',
      entity: {name: 'bar'},
      action: 'R'
    })

  it 'action', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'action=R').total,
      1)

  it 'entity-name', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'entity-name=foo').total,
      1)
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'entity-name=bar').total,
      1)
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'entity-name=muhaha').total,
      0)

  it 'entity-name and action', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'AuditEvent', queryString: 'entity-name=foo,action=R').total,
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

  describe 'by id', ->
    it 'as id', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'Patient',
          queryString: '_id=patient-id'
        ).total,
        1)

    it 'as URL', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'Patient',
          queryString: '_id=http://fhirbase/Patient/patient-id'
        ).total,
        1)

    it 'as URL with history', ->
      assert.equal(
        search.fhir_search(
          plv8,
          resourceType: 'Patient',
          queryString: '_id=http://fhirbase/Patient/patient-id/_history/patient-fake-history-id'
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

describe 'Date search', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    schema.fhir_create_storage(plv8, resourceType: 'Patient')

  beforeEach ->
    schema.fhir_truncate_storage(plv8, resourceType: 'Patient')

  it 'by birthDate', ->
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'Patient'
      birthDate: '1970-01-01'
    })
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'Patient'
      birthDate: '2000-01-01'
    })

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient', queryString: 'birthdate=lt2010').total,
      2)

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient',
        queryString: 'birthdate=ge2000-01-01&birthdate=le2010-01-01'
      ).total,
    1)

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient', queryString: 'birthdate=gt2010').total,
      0)

  it 'with format 1970-12-31T01:23+0300', ->
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'Patient'
      birthDate: '1989-02-07T05:26+0300'
    })

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient', queryString: 'birthdate=lt2000').total,
      1)

  it 'by lastUpdated', ->
    createPatient = (dateString)->
      patient = crud.fhir_create_resource(plv8, resource: {
        resourceType: 'Patient'
      })
      patient.meta.lastUpdated = new Date(dateString)
      plv8.execute(
        '''
        UPDATE patient
        SET created_at = $1::timestamptz,
            updated_at = $1::timestamptz,
            resource = $2
        WHERE id = $3
        ''',
        [JSON.stringify(dateString), JSON.stringify(patient), patient.id]
      )

    createPatient('1970-01-01')
    createPatient('2010-01-01')

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient',
        queryString: '_lastUpdated=eq1970-01-01'
      ).total,
    1)

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient',
        queryString: '_lastUpdated=1970-01-01'
      ).total,
    1)


    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient',
        queryString: '_lastUpdated=lt1970-01-01'
      ).total,
    0)

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient',
        queryString: '_lastUpdated=ge1970-01-01&_lastUpdated=le2010-01-01'
      ).total,
    2)

    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Patient',
        queryString: '_lastUpdated=gt1960-01-01&_lastUpdated=lt2000-01-01'
      ).total,
    1)

describe 'Encounter search', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    schema.fhir_create_storage(plv8, resourceType: 'Encounter')
    schema.fhir_create_storage(plv8, resourceType: 'Patient')

  beforeEach ->
    schema.fhir_truncate_storage(plv8, resourceType: 'Encounter')

    crud.fhir_create_resource(plv8, allowId: true, resource: {
      id: 'patient-id', resourceType: 'Patient', name: [{given: ['John']}]
    })
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'Encounter',
      status: 'planned'
    })
    crud.fhir_create_resource(plv8, resource: {
      resourceType: 'Encounter',
      patient: {reference: 'Patient/patient-id'},
      status: 'finished'
    })

  it 'by patient name', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Encounter',
        queryString: 'patient:Patient.name=John'
        ).total,
      1)

  it 'by status', ->
    assert.equal(
      search.fhir_search(plv8,
        resourceType: 'Encounter',
        queryString: 'status=finished'
        ).total,
      1)

  it 'by patient name AND status should raise error', -> # FIXME: sql "where" and "join" statements mixed up in wrong order #104 <https://github.com/fhirbase/fhirbase-plv8/issues/104>.
    assert.throws(
      (->
        search.fhir_search(
          plv8,
          resourceType: 'Encounter',
          queryString: 'patient:Patient.name=John&status=finished'
        )
      ),
      ((err)->
        (err instanceof Error) &&
          /syntax error at or near "JOIN"/.test(err)
      )
    )
