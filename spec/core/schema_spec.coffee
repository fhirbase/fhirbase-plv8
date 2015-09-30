plv8 = require('../../plpl/src/plv8')
schema = require('../../src/core/schema')
pg_meta = require('../../src/core/pg_meta')

describe "simple", ()->
  it "test", ()->
    schema.drop_table(plv8, 'Users')
    expect(pg_meta.table_exists(plv8, 'users')).toBeFalsy()
    schema.create_table(plv8, 'Users')

    expect(pg_meta.table_exists(plv8, 'users')).toBeTruthy()
    expect(pg_meta.table_exists(plv8, 'history.users')).toBeTruthy()

    desc = schema.describe_table(plv8, 'users')
    expect(desc.name).toEqual('users')

    schema.drop_table(plv8, 'Users')
    expect(pg_meta.table_exists(plv8, 'Users')).toBeFalsy()
    expect(pg_meta.table_exists(plv8, 'history.users')).toBeFalsy()
