schema = require('../src/core/schema')
crud = require('../src/core/crud')

exports.up = (plv8)->
  params = require('../fhir/search-parameters.json')
  types = require('../fhir/profiles-types.json')
  profiles = require('../fhir/profiles-resources.json')

  schema.drop_storage(plv8, resourceType: 'StructureDefinition')
  schema.drop_storage(plv8, resourceType: 'SearchParameter')
  schema.drop_storage(plv8, resourceType: 'OperationDefinition')

  schema.create_storage(plv8, resourceType: 'StructureDefinition')
  schema.create_storage(plv8, resourceType: 'SearchParameter')

  schema.create_storage(plv8, resourceType: 'OperationDefinition')

  crud.load(plv8, params)
  crud.load(plv8, types)
  crud.load(plv8, profiles)

exports.down = (plv8)->
  # plv8.execute ""
  throw new Error('Not implemented')
