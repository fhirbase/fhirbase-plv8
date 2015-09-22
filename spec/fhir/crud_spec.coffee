plv8 = require('../../plpl/src/plv8')
crud = require('../../src/fhir/crud')
schema = require('../../src/fhir/schema')

describe "CRUD", ()->
  beforeEach ()->
    console.log "before"
    plv8.execute schema.create_table(plv8, 'Users')

  afterEach ()->
    console.log "after"
    plv8.execute schema.drop_table(plv8, 'Users')

  it "read", ()->
    console.log "Here"
