plv8 = require('../../plpl/src/plv8')
schema = require('../../src/fhir/schema')

describe "simple", ()->
  it "test", ()->
    expect(schema.table_exists(plv8, 'Users')).toBeFalsy()
    schema.create_table(plv8, 'Users')

    expect(schema.table_exists(plv8, 'users')).toBeTruthy()
    expect(schema.table_exists(plv8, 'history.users')).toBeTruthy()
    desc = schema.describe_table(plv8, 'users')
    expect(desc.name).toEqual('users')

    schema.drop_table(plv8, 'Users')
    expect(schema.table_exists(plv8, 'Users')).toBeFalsy()
