plv8 = require('../../plpl/src/plv8')
meta = require('../../src/core/pg_meta')


describe "CRUD", ()->
  it "simple", ()->
    plv8.execute "DROP TABLE IF EXISTS test_pg_meta"
    plv8.execute "DROP SCHEMA IF EXISTS testo CASCADE"
    plv8.execute "CREATE TABLE test_pg_meta (id serial)"

    plv8.execute "CREATE SCHEMA testo"
    plv8.execute "CREATE TABLE testo.test_pg_meta (id serial)"

    expect(meta.table_exists(plv8, 'test_pg_meta')).toEqual(true)
    expect(meta.table_exists(plv8, 'testo.test_pg_meta')).toEqual(true)
