schema = require('../../src/core/schema')
index = require('../../src/fhir/meta_index')
meta_fs = require('../../src/fhir/meta_fs')
test = require('../helpers.coffee')
assert = require('assert')

specs = test.loadYaml("#{__dirname}/meta_index_spec.yaml", 'utf8')

idx_fs = index.new({}, meta_fs.getter)

describe "fhir.meta_index: file system", ()->
  for espec in specs.elements[0..0]
    it "elements: #{JSON.stringify(espec.query)}", ()->
      assert.deepEqual(index.element(idx_fs, espec.query), espec.result)

  for pspec in specs.params[0..0]
    it "params: #{JSON.stringify(pspec.query)}", ()->
      assert.deepEqual(index.parameter(idx_fs, pspec.query), pspec.result)

plv8 = require('../../plpl/src/plv8')
# plv8.debug = true
meta_db = require('../../src/fhir/meta_pg')
idx_db = index.new(plv8, meta_db.getter)

describe "fhir.meta_index: data base", ()->
  for espec in specs.elements[0..0]
    it "elements: #{JSON.stringify(espec.query)}", ()->
      assert.deepEqual(index.element(idx_db, espec.query), espec.result)

  for pspec in specs.params[0..0]
    it "params: #{JSON.stringify(pspec.query)}", ()->
      assert.deepEqual(index.parameter(idx_db, pspec.query), pspec.result)
