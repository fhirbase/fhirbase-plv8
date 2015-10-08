index = require('../../src/fhir/meta_index')
meta_fs = require('../../src/fhir/meta_fs')
test = require('../helpers.coffee')
assert = require('assert')

specs = test.loadYaml("#{__dirname}/meta_index_spec.yaml", 'utf8')

idx = index.new(meta_fs.getter)

describe "CRUD", ()->
  it "elements", ()->
    for spec in specs.elements[0..0]
      assert.deepEqual(index.element(idx, spec.query), spec.result)

  it "params", ()->
    for spec in specs.params[0..0]
      assert.deepEqual(index.parameter(idx, spec.query), spec.result)
