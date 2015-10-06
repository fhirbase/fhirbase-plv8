resources = require('../../fhir/profiles-resources.json')
types = require('../../fhir/profiles-types.json')

resources.entry = resources.entry.concat(types.entry)

search_params = require('../../fhir/search-parameters.json')

exports.adapter = (_)->

  cache = {}
  sp_idx = {}
  el_idx = {}
  res_idx = {}

  find_structure_definition = (resourceType)->
    key = resourceType
    unless res_idx[key]
      res = resources.entry.filter (x)->
        x.resource.name == resourceType
      res = resources.entry.filter (x)->
        x.resource.name == resourceType
      unless res[0]
        throw new Error("Could not find resource #{resourceType}")
      res_idx[key] = res[0].resource
    res_idx[key]

  find_parameter: (resourceType, name)->
    key = "#{resourceType}-#{name}"
    unless sp_idx[key]
      res = search_params.entry.filter (x)->
        x.resource.base == resourceType && x.resource.name == name
      unless res[0]
        throw new Error("Could not find search parameter #{resourceType} #{name}")
      sp_idx[key] = res[0].resource
    sp_idx[key]

  find_element: (path)->
    epath = path.join('.')
    unless cache[epath]
      profile = find_structure_definition(path[0])
      res = profile.snapshot.element.filter (x)-> x.path == epath
      unless res[0]
        throw new Error("Element #{path} not found")
      cache[epath] = res[0]
    cache[epath]
