plv8 = require('../plpl/src/plv8')
assert = require('assert')


describe "Integration",->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
  it "main api test", -> 
    plv8.execute("select drop_storage($1)", [JSON.stringify(resourceType: "Patient")])
    plv8.execute("select create_storage($1)", [JSON.stringify(resourceType: "Patient")])
    plv8.execute("select index_parameter($1)", [JSON.stringify(resourceType: "Patient", name: "name")])
    plv8.execute("select create_resource($1)", [JSON.stringify(resourceType: "Patient", name: [{given: "nicola"}])])
    res = plv8.execute("select search($1)", [JSON.stringify(resourceType: "Patient", queryString: 'name=nicola')])
    bundle = JSON.parse(res[0].search)
    assert.equal(bundle.total, 1)
    assert.equal(bundle.entry[0].resource.name[0].given, 'nicola')

