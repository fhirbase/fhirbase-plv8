plv8 = require('../plpl/src/plv8')
bench = require('../src/benchmark')
assert = require('assert')

describe 'Benchmarking', ->
  before ->
    plv8.execute("SET plv8.start_proc = 'plv8_init'")
    ['Patient', 'Encounter', 'Organization', 'Practitioner'].forEach (r)->
      plv8.execute(
        'SELECT fhir_create_storage($1)',
        [JSON.stringify(resourceType: r)]
      )

  it 'Benchmark', ->
    this.timeout(60000) # may takes longer time than default 2000 milliseconds <https://mochajs.org/#timeouts>
    benchmark = plv8.execute('SELECT fhir_benchmark($1::json)', [JSON.stringify({})])
    assert.equal(
      JSON.parse(benchmark[0].fhir_benchmark).operations[0].description,
      'fhir_create_resource called just one time'
    )
    assert.equal(
      !!JSON.parse(benchmark[0].fhir_benchmark).operations[0]
        .time.toString().match(/[0-9.]+/),
      true
    )

  it 'Dissoc', ->
    object = plv8.execute(
      'SELECT fhir_benchmark_dissoc($1::json, $2::text)',
       [JSON.stringify({foo: 'bar', xyz: 123}),
        'foo']
    )
    assert.deepEqual(
      JSON.parse(object[0].fhir_benchmark_dissoc),
      {xyz: 123}
    )

  it 'Merge', ->
    object = plv8.execute(
      'SELECT fhir_benchmark_merge($1::json, $2::json)',
       [JSON.stringify({foo: 'bar'}),
        JSON.stringify({xyz: 123})]
    )
    assert.deepEqual(
      JSON.parse(object[0].fhir_benchmark_merge),
      {foo: 'bar', xyz: 123}
    )
