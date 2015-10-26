plv8 = require('../../plpl/src/plv8')
meta = require('../../src/core/pg_meta')
assert = require('assert')

describe "CORE: pg meta", ()->
  it "drop and create table", ()->
    plv8.execute "DROP TABLE IF EXISTS test_pg_meta CASCADE"
    plv8.execute "DROP SCHEMA IF EXISTS testo CASCADE"
    plv8.execute "CREATE TABLE test_pg_meta (id serial)"

    plv8.execute "CREATE SCHEMA testo"
    plv8.execute "CREATE TABLE testo.test_pg_meta (id serial)"

    assert.equal(meta.table_exists(plv8, 'test_pg_meta'), true)
    assert.equal(meta.table_exists(plv8, 'testo.test_pg_meta'), true)
