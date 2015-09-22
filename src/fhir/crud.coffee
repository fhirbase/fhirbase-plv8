utils = require('./utils')

exports.plv8_schema = 'fhir'

exports.create = (plv8, resource)->
  console.log(utils.table_name("Patient"))
  console.log('create')

exports.create.plv8_signature = ['jsonb', 'jsonb']

exports.update = (plv8, resource)->
  console.log('update')

exports.update.plv8_signature = ['jsonb', 'jsonb']

exports.delete = (plv8, resource_type, id)->
  console.log('delete')

exports.delete.plv8_signature = ['text', 'text', 'jsonb']

exports.read = (plv8, resource_type, id)->
  console.log('read')

exports.delete.plv8_signature = ['text', 'text', 'jsonb']


exports.vread = (plv8, resource_type, id, version_id)->
  console.log('vread')

exports.delete.plv8_signature = ['text', 'text', 'text', 'jsonb']
