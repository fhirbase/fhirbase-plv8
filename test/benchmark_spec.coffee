plv8 = require('../plpl/src/plv8')
assert = require('assert')

describe 'Benchmark', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")

  it 'benchmark', ->
    benchmark = plv8.execute('SELECT fhir_benchmark($1)', [JSON.stringify({})])
    assert.equal(
      JSON.parse(benchmark[0].fhir_benchmark).operations[0].description,
      'fhir.fhir_create_resource called just one time'
    )
    assert.equal(
      !!JSON.parse(benchmark[0].fhir_benchmark).operations[0]
        .time.match(/[0-9.]+ [a-z]+/),
      true
    )
