test = require('../helpers.coffee')
assert = require('assert')
elements = require('../../src/fhir/search_elements')

specs = test.loadYaml("#{__dirname}/search_elements_spec.yaml", 'utf8')

describe "CORE: param to element", ()->
  specs.param_to_elements.forEach (x)->
    it x.args, ()->
      assert.deepEqual(elements.parse_elements(x.args), x.result)

describe "elements: filter", ()->
  specs.elements.forEach (x)->
    it JSON.stringify(x.filter), ()->
      assert.deepEqual(elements.elements(x.resource, x.filter), x.result)

structure_definitions = require('../../fhir/profiles-resources.json')

pt_sd = structure_definitions
  .entry
  .filter((x)-> x.resource.name == 'Patient')[0]
  .resource

pt =
  resourceType: 'Patient'
  gender: 'male'
  photo: 'ups'

expected_pt =
  resourceType: 'Patient'
  gender: 'male'

pt_summary_els = [ 'resourceType',
  'id',
  'meta',
  'implicitRules',
  'identifier',
  'active',
  'name',
  'telecom',
  'gender',
  'birthDate',
  'deceasedBoolean',
  'deceasedDateTime',
  'address',
  'contact.modifierExtension',
  'animal',
  'animal.modifierExtension',
  'animal.species',
  'animal.breed',
  'animal.genderStatus',
  'communication.modifierExtension',
  'managingOrganization',
  'link',
  'link.modifierExtension',
  'link.other',
  'link.type' ]

describe "elements: filter", ()->
  it "summary elements", ->
    els = elements.summary_elements(pt_sd)
    assert.deepEqual(pt_summary_els, els)

  it "summary selector", ->
    sel = elements.summary_selector(pt_sd)
    filtered = elements.elements(pt, sel)
    assert.deepEqual(expected_pt, filtered)
