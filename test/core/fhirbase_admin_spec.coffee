assert = require('assert')
plv8 = require('../../plpl/src/plv8')
fhirbaseAdmin = require('../../src/core/fhirbase_admin')

describe 'Fhirbase should know', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'disk usage', ->
    diskUsage = fhirbaseAdmin.fhirbase_disk_usage_top(plv8, {limit: 11})
    assert.equal(diskUsage.length, 11)
