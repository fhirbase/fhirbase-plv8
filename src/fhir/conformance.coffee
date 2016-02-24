utils = require('../core/utils')
compat = require('../compat')

exports.fhir_conformance = (plv8, base)->
  base.resourceType = 'Conformance'
  base.version =  base.version || 'fhirbase-0.0.2'
  base.acceptUnknown = true

  schema = utils.current_schema(plv8)


  tables = utils.exec plv8,
    select: ':*'
    from: ':pg_tables'
    where: ['$and',
      ['$eq', ':schemaname', schema]
      ['$ilike', ':tablename', "%_history"]]

  resources = tables.map((x)-> x.tablename.replace('_history', ''))

  profiles = utils.exec(plv8,
    select: ':*'
    from: ':structuredefinition'
    where: ['$in', ':lower(id)', resources]
  ).map((x)-> compat.parse(plv8, x.resource))

  base.rest = [
    mode: 'server'
    resource: profiles.map (p)->
      type: p.name
      versioning: 'versioned'
      profile:
        reference:  "/fhir/StructureDefinition/#{p.name}"
      interaction: ["read","vread","update","delete","history-instance","validate","history-type","create","search-type"].map((tp)-> {code: tp})
  ]
  base


exports.fhir_conformance.plv8_signature = ['json', 'json']
