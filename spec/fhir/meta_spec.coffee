plv8 = require('../../plpl/src/plv8')
schema = require('../../src/core/schema')
pg_meta = require('../../src/core/pg_meta')
utils = require('../../src/core/utils')
meta = require('../../src/fhir/meta')
search = require('../../src/core/search')

# types = require('../../fhir/profiles-types.json')
# resources = require('../../fhir/profiles-resources.json')

# schema.drop_table(plv8, 'StructureDefinition')
# schema.drop_table(plv8, 'OperationDefinition')

# schema.create_table(plv8, 'StructureDefinition')
# schema.create_table(plv8, 'OperationDefinition')

# meta.load(plv8, types)
# meta.load(plv8, resources)


console.log search.search(plv8, {
  resourceType: 'StructureDefinition'
  query: ['.kind', '=', 'datatype']
})
