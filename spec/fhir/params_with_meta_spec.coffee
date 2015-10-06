params = require('../../src/fhir/params_with_meta')
meta = require('../../src/fhir/meta_fs')

pt_profile = require('./fixtures/patient.json')

cache = {}

find_structure_definition = (resourceType)->
  pt_profile

adapter = meta.adapter()

specs = []

specs.push
  query:
    resourceType: 'Patient'
    params: [{value: 'ivan', name: 'name'}]
  result:
    resourceType: 'Patient',
    params: [
      name: 'name'
      searchType: 'string'
      elementType: 'HumanName'
      path: ['Patient','name']
      pathUsage: "normal"
      multiple: true
      value: 'ivan'
    ]

# specs.push
#   query:
#     resourceType: 'Patient'
#     params: [{value: 'ivan', name: 'given'}]
#   result:
#     resourceType: 'Patient',
#     params: [
#       name: 'name'
#       searchType: 'string'
#       elementType: 'string'
#       path: ['Patient','name', 'given']
#       pathUsage: "normal"
#       multiple: true
#       value: 'ivan'
#     ]

describe "Params with meta", ()->
   it "params", ()->
     for spec in specs
       expect(params._expand(adapter, spec.query)).toEqual(spec.result)
