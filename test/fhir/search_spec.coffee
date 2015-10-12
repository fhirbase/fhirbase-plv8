search = require('../../src/fhir/search')
schema = require('../../src/core/schema')
honey = require('../../src/honey')
assert = require('assert')
plv8 = require('../../plpl/src/plv8')

# index = require('../../src/fhir/meta_index')
# meta_fs = require('../../src/fhir/meta_fs')
# idx = index.new(meta_fs.getter)

# res = search._search_sql(plv8, idx, {resourceType: 'Patient', queryString: 'name=ivan,nicola'})
# console.log(res)
# console.log honey(res)

# describe "simple", ()->
#   it "test", ()->
#     schema.drop_storage(plv8, 'patient')
#     schema.create_storage(plv8, 'patient')

