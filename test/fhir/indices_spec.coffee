search = require('../../src/fhir/search')
schema = require('../../src/core/schema')
crud = require('../../src/fhir/crud')
honey = require('../../src/honey')
plv8 = require('../../plpl/src/plv8')
fs = require('fs')
test = require('../helpers.coffee')

assert = require('assert')

# plv8.execute("SET plv8.start_proc = 'plv8_init'")
# plv8.execute("DROP INDEX IF EXISTS patient_name_string")
# console.log search.index_parameter(plv8, resourceType: 'Patient', name: 'name')
