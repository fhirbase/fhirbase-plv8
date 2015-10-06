index = require('../../src/fhir/meta_index')
test = require('../helpers.coffee')

specs = test.loadYaml("#{__dirname}/meta_index_spec.yaml", 'utf8')

idx = {}

idx = index.add(idx, require('./fixtures/patient.json'))
idx = index.add(idx, require('./fixtures/human_name.json'))
idx = index.add(idx, require('./fixtures/address.json'))
idx = index.add(idx, require('./fixtures/period.json'))


describe "CRUD", ()->
  it "simple", ()->
    for spec in specs
      expect(index.find(idx, spec.query)).toEqual(spec.result)
