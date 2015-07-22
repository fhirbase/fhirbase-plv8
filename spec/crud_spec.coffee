plv8 = require('../lib/plv8')
crud = require('../src/crud')
schema = require('../src/schema')

test_read = (res)->
  res = JSON.parse(res)
  expect(res.resourceType).toEqual('StructureDefinition')

describe "CRUD", ()->
  beforeEach ()->
    schema.generate_table(plv8, 'Patient')

  afterEach ()->
    schema.drop_table(plv8, 'Patient')

  it "read", ()->
    pt = {resourceType: 'Patient', name: {text: 'Albert'}}
    pt_created = crud.create(plv8, pt)
    expect(pt_created.id).toBeTruthy()
    expect(pt_created.meta.versionId).toBeTruthy()
    id = pt_created.id

    pt_read = crud.read(plv8, 'Patient', id)
    expect(pt_read).toEqual(pt_created)

    pt_to_update = {resourceType: 'Patient', id: id, name: {text: 'Palbert'}}
    pt_updated = crud.update(plv8,  pt_to_update)
    expect(pt_updated.meta).toBeTruthy()
    expect(pt_updated.meta.versionId).toBeTruthy()
    expect(pt_updated.meta.versionId).not.toEqual(pt_created.meta.versionId)

    old_pt = crud.vread(plv8, 'Patient', pt_created.meta.versionId)
    expect(old_pt).toEqual(pt_created)

    new_pt = crud.vread(plv8, 'Patient', pt_updated.meta.versionId)
    expect(new_pt).toEqual(pt_updated)

    expect(crud.read(plv8, 'Patient', id)).toEqual(pt_updated)

    uuid = (plv8)->
      plv8.execute('select gen_random_uuid() as uuid')[0].uuid
    outcome = crud.read(plv8, 'Patient', uuid(plv8))
    expect(outcome.resourceType).toEqual('OperationOutcome')
    console.log 'outcome', outcome
    expect(outcome.issue[0].code.coding[0].code).toEqual('404')

    # crud.delete(plv8, 'Patient', id)
    # outcome = crud.read(plv8, 'Patient', id)
    # expect(outcome.resourceType).toEqual('OperationOutcome')
    # expect(outcome.issue[0])

  it "read in db", ()->
    np = require('../lib/node2pl')
    np.scan('../src/crud')

    res = plv8.execute("select fhir.read('StructureDefinition', 'Patient') as read")[0]['read']
