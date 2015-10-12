search = require('../../src/fhir/search')
assert = require('assert')

index = require('../../src/fhir/meta_index')
meta_fs = require('../../src/fhir/meta_fs')
idx = index.new(meta_fs.getter)

# res = search._search_sql(idx, {resourceType: 'Patient', queryString: 'birthdate=lt2010-01-01&name=ivan&given=ivanov'})
# console.log res

res = search._search_sql(idx, {resourceType: 'Patient', queryString: 'name=ivan,nicola'})
console.log res
