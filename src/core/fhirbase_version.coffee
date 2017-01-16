fhirbase_version = -> '1.6.0.1'

exports.fhirbase_version = fhirbase_version

exports.fhirbase_version.plv8_signature = {
  arguments: 'json'
  returns: 'varchar(20)'
  immutable: true
}

fhirbase_release_date = -> '2017-01-16T10:00:00Z'

exports.fhirbase_release_date = fhirbase_release_date

exports.fhirbase_release_date.plv8_signature = {
  arguments: 'json'
  returns: 'varchar(50)'
  immutable: true
}
