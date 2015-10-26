crud = require('../core/crud.coffee')

exports.translate = (bundle)->
  response = []
  for entry in bundle.entry
    res = null
    if entry.request.method == 'POST'
      res = {action: "create", resource: entry.resource}
    else if entry.request.method == 'PUT'
      res = {action: 'update', resource: entry.resource}
    else if entry.request.method == 'DELETE'
      parts = entry.request.url.split('/')
      res = {action: 'delete', resource: {id: parts[1], resourceType: parts[0]}}
    if res
      response.push res
  response

exports.transaction = (plv8, bundle)->
  for entry in bundle.entry
    if entry.request.method == 'POST'
      crud.create plv8, entry.resource

  resourceType: 'Bundle',
  id: 'bundle-transaction',
  type: 'transaction-response'
  entry: []
