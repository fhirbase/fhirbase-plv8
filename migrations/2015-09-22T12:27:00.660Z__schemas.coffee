sql = require('../src/honey')

exports.up = (plv8)->
  plv8.execute sql({create: 'schema', name: 'fhir'})

exports.down = (plv8)->
  plv8.execute sql({drop: 'schema', name: 'fhir'})
