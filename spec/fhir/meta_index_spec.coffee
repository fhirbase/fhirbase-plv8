index = require('../../src/fhir/meta_index')
test = require('../helpers.coffee')

specs = test.loadYaml("#{__dirname}/meta_index_spec.yaml", 'utf8')

getter = (rt, query)->
  params = require('../../fhir/search-parameters.json')
  if rt == 'StructureDefinition'
    sds =
      Patient: require('./fixtures/patient.json')
      HumanName: require('./fixtures/human_name.json')
      Address: require('./fixtures/address.json')
      Period: require('./fixtures/period.json')
    sds[query.name]
  else
    res = params.entry.filter (x)->
      x.resource.base == query.base && x.resource.name == query.name
    if res.length > 1
      throw new Error("Unexpected behavior")

    res[0] && res[0].resource

idx = index.new(getter)

describe "CRUD", ()->
  it "elements", ()->
    for spec in specs.elements[0..0]
      expect(index.element(idx, spec.query)).toEqual(spec.result)

  it "params", ()->
    for spec in specs.params[0..0]
      expect(index.parameter(idx, spec.query)).toEqual(spec.result)
