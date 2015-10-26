crud = require('../core/crud.coffee')

exports.translate = (bundle)->
  []

exports.transaction = (plv8, bundle)->
  for entry in bundle.entry
    if entry.request.method == 'POST'
      crud.create plv8, entry.resource

  resourceType: 'Bundle',
  id: 'bundle-transaction',
  type: 'transaction-response'
  entry: []
