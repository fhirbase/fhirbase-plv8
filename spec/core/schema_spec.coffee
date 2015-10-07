plv8 = require('../../plpl/src/plv8')
schema = require('../../src/core/schema')
pg_meta = require('../../src/core/pg_meta')
assert = require('assert')

describe "simple", ()->
  it "test", ()->
    schema.drop_table(plv8, 'Users')
    assert.equal(pg_meta.table_exists(plv8, 'users'), false)
    schema.create_table(plv8, 'Users')

    assert.equal(pg_meta.table_exists(plv8, 'users'), true)
    assert.equal(pg_meta.table_exists(plv8, 'history.users'), true)

    desc = schema.describe_table(plv8, 'users')
    assert.equal(desc.name, 'users')

    schema.drop_table(plv8, 'Users')
    assert.equal(pg_meta.table_exists(plv8, 'Users'), false)
    assert.equal(pg_meta.table_exists(plv8, 'history.users'), false)
