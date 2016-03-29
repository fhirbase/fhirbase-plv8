plv8 = require('../plpl/src/plv8')
assert = require('assert')

describe 'Benchmarking', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    plv8.execute(
      'SELECT fhir_create_storage($1)',
      [JSON.stringify(resourceType: 'Patient')]
    )

  it 'Benchmark', ->
    benchmark = plv8.execute('SELECT fhir_benchmark($1)', [JSON.stringify({})])
    assert.equal(
      JSON.parse(benchmark[0].fhir_benchmark).operations[0].description,
      'fhir_create_resource called just one time'
    )
    assert.equal(
      !!JSON.parse(benchmark[0].fhir_benchmark).operations[0]
        .time.match(/[0-9.]+ [a-z]+/),
      true
    )

  it 'Dissoc', ->
    object = plv8.execute(
      'SELECT fhir_benchmark_dissoc($1, $2)',
       [JSON.stringify({foo: 'bar', xyz: 123}),
        'foo']
    )
    assert.deepEqual(
      JSON.parse(object[0].fhir_benchmark_dissoc),
      {xyz: 123}
    )
