params = require('../../src/fhir/params_with_meta')

pt_profile = require('./patient.json')

find_structure_definition = (resourceType, path)->
  pt_profile

adapter = {
  find_parameter: (resourceType, name)->
    {
      "resourceType": "SearchParameter",
      "base": "Patient",
      "id": "Patient-name",
      "name": "name",
      "type": "string",
      "xpath": "f:Patient/f:name",
      "xpathUsage": "normal"
    }
  find_element: (resourceType, path)->
    profile = find_structure_definition(resourceType)
    epath = path.join('.')
    console.log(epath)
    res = profile.snapshot.element.filter (x)-> x.path == epath
    console.log(res)
    res[0]
}

query =
  resourceType: 'Patient'
  params: [{value: 'ivan', name: 'name'}]

result =
  resourceType: 'Patient',
  params: [
    {
      name: 'name'
      searchType: 'string'
      elementType: 'HumanName'
      path: ['Patient','name']
      pathUsage: "normal"
      multiple: true
      value: 'ivan'
    }
  ]

describe "Params with meta", ()->
   it "params", ()->
     expect(params._expand(adapter,query)).toEqual(result)
