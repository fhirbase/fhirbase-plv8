fhir_benchmark = (plv8, query)->
  {
    operations: [
      {
        description: 'fhir.fhir_create_resource called just one time'
        time: '0.666 ms'
      }
    ]
  }

exports.fhir_benchmark = fhir_benchmark
exports.fhir_benchmark.plv8_signature = ['json', 'json']
