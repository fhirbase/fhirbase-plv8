namings = require('./namings')
pg_meta = require('./pg_meta')
utils = require('./utils')
bundle = require('./bundle')

exports.plv8_schema = "core"

validate_create_resource = (resource)->
  unless resource.resourceType
    {status: "Error", message: "resource should have type element"}

assert = (pred, msg)-> throw new Error("Asserted: #{msg}") unless pred

ensure_meta = (resource, props)->
  resource.meta ||= {}
  for k,v of props
    resource.meta[k] = v
  resource

ensure_table = (plv8, resourceType)->
  table_name = namings.table_name(plv8, resourceType)
  unless pg_meta.table_exists(plv8, table_name)
    return [null, {status: "Error", message: "Table #{table_name} for #{resourceType} not exists"}]
  else
    [table_name, null]

exports.create = (plv8, resource)->
  errors = validate_create_resource(resource)
  return errors if errors


  [table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors


  id = resource.id || utils.uuid(plv8)
  resource.id = id
  version_id = (resource.meta && resource.meta.versionId) ||  utils.uuid(plv8)


  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    request: { method: 'POST', url: resource.resourceType }

  utils.exec plv8,
    insert: table_name
    values:
      id: id
      version_id: version_id
      resource: resource
      created_at: '^CURRENT_TIMESTAMP'
      updated_at: '^CURRENT_TIMESTAMP'

  utils.exec plv8,
    insert: ['history',table_name]
    values:
      id: id
      version_id: version_id
      resource: resource
      valid_from: '^CURRENT_TIMESTAMP'
      valid_to: '^CURRENT_TIMESTAMP'

  resource

exports.create.plv8_signature = ['json', 'json']

exports.read = (plv8, query)->
  assert(query.id, 'query.id')
  assert(query.resourceType, 'query.resourceType')

  [table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  res = utils.exec(plv8, select: [':*'], from: [table_name], where: { id: query.id })
  row = res[0]
  unless row
    return {status: "Error", message: "Not found"}

  JSON.parse(row.resource)

exports.read.plv8_signature = ['json', 'json']

exports.vread = (plv8, query)->
  assert(query.id, 'query.id')
  version_id = query.versionId || query.meta.versionId
  assert(version_id, 'query.versionId or query.meta.versionId')
  assert(query.resourceType, 'query.resourceType')

  [table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  q =
    select: [':*']
    from: ["history.#{table_name}"]
    where: {id: query.id, version_id: version_id}

  res = utils.exec(plv8,q)
  row = res[0]
  unless row
    return {status: "Error", message: "Not found"}

  JSON.parse(row.resource)

exports.vread.plv8_signature = ['json', 'json']

exports.update = (plv8, resource)->
  id = resource.id
  assert(id, 'resource.id')
  assert(resource.resourceType, 'resource.resourceType')

  [table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  old_version = exports.read(plv8, resource)

  unless old_version
    return {status: "Error", message: "Resource #{resource.resourceType}/#{id} not exists"}

  version_id = utils.uuid(plv8)

  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    request:
      method: 'PUT'
      url: resource.resourceType

  utils.exec plv8,
    update: table_name
    where: {id: id}
    values:
      version_id: version_id
      resource: resource
      updated_at: '^CURRENT_TIMESTAMP'

  utils.exec plv8,
    update: ['history', table_name]
    where: {id: id, version_id: old_version.meta.versionId}
    values: {valid_to: '^CURRENT_TIMESTAMP'}

  utils.exec plv8,
    insert: ['history',table_name]
    values:
      id: id
      version_id: version_id
      resource: resource
      valid_from: '^CURRENT_TIMESTAMP'
      valid_to: "^'infinity'"

  resource


exports.update.plv8_signature = ['json', 'json']

exports.delete = (plv8, resource)->
  id = resource.id
  assert(id, 'resource.id')
  assert(resource.resourceType, 'resource.resourceType')

  [table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  old_version = exports.read(plv8, resource)

  unless old_version
    return {status: "Error", message: "Resource #{resource.resourceType}/#{id} not exists"}

  resource = utils.copy(old_version)

  version_id = utils.uuid(plv8)

  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    request:
      method: 'DELETE'
      url: resource.resourceType

  utils.exec plv8,
    delete: table_name
    where: { id: id }

  utils.exec plv8,
    update: ['history', table_name]
    where: {id: id, version_id: old_version.meta.versionId}
    values: {valid_to: '^CURRENT_TIMESTAMP'}

  utils.exec plv8,
    insert: ['history', table_name]
    values:
      id: id
      version_id: version_id
      resource: resource
      valid_from: '^CURRENT_TIMESTAMP'
      valid_to: '^CURRENT_TIMESTAMP'

  resource


exports.delete.plv8_signature = ['json', 'json']

exports.history = (plv8, query)->
  id = query.id
  assert(id, 'query.id')
  assert(query.resourceType, 'query.resourceType')

  [table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  resources = utils.exec( plv8,
    select: [':*']
    from:   ["history.#{table_name}"]
    where:  {id: query.id}
  ).map((x)-> JSON.parse(x.resource))

  bundle.history_bundle(resources)

# TODO: implement load bundle
# TODO: implement merge bundle
