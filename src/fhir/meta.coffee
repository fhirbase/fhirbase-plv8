schema = require('../core/schema')
crud = require('../core/crud')

exports.load = (plv8, bundle)->
  for entry in bundle.entry
    console.log "insert", entry.resource.resourceType, ':', entry.resource.id
    res = crud.create(plv8, entry.resource)
    if res.status == 'error'
      console.log(res)
