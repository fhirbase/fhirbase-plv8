search = require('../../src/fhir/search')
schema = require('../../src/core/schema')
honey = require('../../src/honey')
assert = require('assert')
plv8 = require('../../plpl/src/plv8')


# res = search.search(plv8, {resourceType: 'Patient', queryString: 'name=ivan,nicola'})
# console.log(res)

# describe "simple", ()->
#   it "test", ()->
#     schema.drop_storage(plv8, 'patient')
#     schema.create_storage(plv8, 'patient')

