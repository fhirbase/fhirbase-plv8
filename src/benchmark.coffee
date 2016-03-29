fhir_benchmark = (plv8, query)->
  create_patients = (count)->
    plv8.execute(
      '''
      SELECT count(
               fhir_create_resource(
                 fhir_benchmark_dissoc(patients.resource, 'id')::json
               )
             )
             FROM (SELECT resource FROM patient LIMIT $1) patients;
      ''',
      [count]
    )

  create_patients(1)

  {
    operations: [
      {
        description: 'fhir_create_resource called just one time'
        time: '0.666 ms'
      }
    ]
  }

exports.fhir_benchmark = fhir_benchmark
exports.fhir_benchmark.plv8_signature = ['json', 'json']

fhir_benchmark_dissoc = (plv8, object, property)->
  object[property] = undefined
  object

exports.fhir_benchmark_dissoc = fhir_benchmark_dissoc

exports.fhir_benchmark_dissoc.plv8_signature = {
  arguments: ['jsonb', 'text']
  returns: 'jsonb'
  immutable: true
}
