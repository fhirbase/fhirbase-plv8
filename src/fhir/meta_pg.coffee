utils = require('../core/utils')

exports._initialize = (plv8)->
  schema = require('../../src/core/schema')
  crud = require('../../src/core/crud')

  params = require('../../fhir/search-parameters.json')
  types = require('../../fhir/profiles-types.json')
  profiles = require('../../fhir/profiles-resources.json')

  # schema.drop_storage(plv8, 'StructureDefinition')
  # schema.drop_storage(plv8, 'SearchParameter')

  # schema.create_storage(plv8, 'StructureDefinition')
  # schema.create_storage(plv8, 'SearchParameter')

  crud.load(plv8, params)
  crud.load(plv8, types)
  crud.load(plv8, profiles)


exports.getter = (plv8, rt, query)->
  console.log(plv8, rt, query)
  res  = if rt == 'StructureDefinition'
    utils.exec plv8,
      select:[':*']
      from: [rt.toLowerCase()]
      where: [':=', "^resource->>'name'", query.name]
  else
    utils.exec plv8,
      select:[':*']
      from: [rt.toLowerCase()]
      where: [':AND', [':=', "^resource->>'name'", query.name],
                      [':=', "^resource->>'base'", query.baes]]

  if res.length > 1
    throw new Error("Unexpected behavior: more then one #{rt} #{JSON.stringify(query)}\n #{JSON.stringify(res.map((x)-> x.resource.id))}")

  if res.length == 1
    throw new Error("Not found #{rt} #{JSON.stringify(query)}")

  res[0]
