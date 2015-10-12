schema = require('../../src/core/schema')
index = require('../../src/fhir/meta_index')
meta_fs = require('../../src/fhir/meta_fs')
test = require('../helpers.coffee')
assert = require('assert')

specs = test.loadYaml("#{__dirname}/meta_index_spec.yaml", 'utf8')

idx_fs = index.new({}, meta_fs.getter)

describe "FS", ()->
  it "elements", ()->
    for spec in specs.elements[0..0]
      assert.deepEqual(index.element(idx_fs, spec.query), spec.result)

  it "params", ()->
    for spec in specs.params[0..0]
      assert.deepEqual(index.parameter(idx_fs, spec.query), spec.result)

# plv8 = require('../../plpl/src/plv8')
# meta_db = require('../../src/fhir/meta_pg')
# meta_db._initialize(plv8)
# idx_db = index.new(plv8, meta_db.getter)

# describe "DB", ()->

#   it "elements", ()->

#     for spec in specs.elements[0..0]
#       assert.deepEqual(index.element(idx_db, spec.query), spec.result)

#   it "params", ()->
#     for spec in specs.params[0..0]
#       assert.deepEqual(index.parameter(idx_db, spec.query), spec.result)
