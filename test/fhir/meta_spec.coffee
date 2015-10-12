plv8 = require('../../plpl/src/plv8')
schema = require('../../src/core/schema')
pg_meta = require('../../src/core/pg_meta')
utils = require('../../src/core/utils')
meta = require('../../src/fhir/meta')
search = require('../../src/core/search')

# types = require('../../fhir/profiles-types.json')
# resources = require('../../fhir/profiles-resources.json')
# sp = require('../../fhir/search-parameters.json')

# schema.drop_storage(plv8, 'StructureDefinition')
# schema.drop_storage(plv8, 'OperationDefinition')

# schema.drop_storage(plv8, 'SearchParameter')

# schema.create_storage(plv8, 'StructureDefinition')
# schema.create_storage(plv8, 'OperationDefinition')

# schema.create_storage(plv8, 'SearchParameter')

# meta.load(plv8, types)
# meta.load(plv8, resources)
# meta.load(plv8, sp)


# console.log search.search(plv8, {
#  resourceType: 'SearchParameter'
#  query: ['.base', '=', 'Patient']
# }).entry
