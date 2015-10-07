index = require('../../src/fhir/meta_index')
meta_fs = require('../../src/fhir/meta_fs')
test = require('../helpers.coffee')

idx = index.new(meta_fs.getter)

sp = require('../../fhir/search-parameters.json')

errors = 0
for entry in sp.entry
  base = entry.resource.base
  name = entry.resource.name
  try
    index.parameter(idx, [base, name])
  catch e
    errors += 1
    console.log(e)

console.log "Number of errors #{errors}"
