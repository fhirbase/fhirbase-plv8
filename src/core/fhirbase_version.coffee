fhirbase_version = -> '1.3.0.13'

exports.fhirbase_version = fhirbase_version

exports.fhirbase_version.plv8_signature = {
  arguments: 'json'
  returns: 'varchar(20)'
  immutable: true
}

fhirbase_release_date = -> '2016-04-27T14:00:00Z'

exports.fhirbase_release_date = fhirbase_release_date

exports.fhirbase_release_date.plv8_signature = {
  arguments: 'json'
  returns: 'varchar(50)'
  immutable: true
}
