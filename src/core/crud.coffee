namings = require('./namings')
pg_meta = require('./pg_meta')
utils = require('./utils')
sql = require('../honey')
bundle = require('./bundle')

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
  hx_table_name = namings.history_table_name(plv8, resourceType)
  unless pg_meta.table_exists(plv8, table_name)
    return [null, null, {status: "Error", message: "Table #{table_name} for #{resourceType} not exists"}]
  else
    [table_name, hx_table_name, null]

create_resource = (plv8, resource)->
  errors = validate_create_resource(resource)
  return errors if errors


  [table_name, hx_table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors


  id = resource.id || utils.uuid(plv8)
  resource.id = id
  version_id = (resource.meta && resource.meta.versionId) ||  utils.uuid(plv8)


  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    request: { method: 'POST', url: resource.resourceType }

  utils.exec plv8,
    insert: sql.q(table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      created_at: sql.now
      updated_at: sql.now

  utils.exec plv8,
    insert: sql.q(hx_table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      valid_from: sql.now
      valid_to: sql.now

  resource

exports.create_resource = create_resource
exports.create_resource.plv8_signature = ['json', 'json']

read_resource = (plv8, query)->
  assert(query.id, 'query.id')
  assert(query.resourceType, 'query.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  res = utils.exec(plv8, select: sql.raw('*'), from: sql.q(table_name), where: { id: query.id })
  row = res[0]
  unless row
    return {status: "Error", message: "Not found"}

  JSON.parse(row.resource)

exports.read_resource = read_resource
exports.read_resource.plv8_signature = ['json', 'json']

exports.vread_resource = (plv8, query)->
  assert(query.id, 'query.id')
  version_id = query.versionId || query.meta.versionId
  assert(version_id, 'query.versionId or query.meta.versionId')
  assert(query.resourceType, 'query.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  q =
    select: sql.raw('*')
    from: sql.q(hx_table_name)
    where: {id: query.id, version_id: version_id}

  res = utils.exec(plv8,q)
  row = res[0]
  unless row
    return {status: "Error", message: "Not found"}

  JSON.parse(row.resource)

exports.vread_resource.plv8_signature = ['json', 'json']

update_resource = (plv8, resource)->
  id = resource.id
  assert(id, 'resource.id')
  assert(resource.resourceType, 'resource.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  old_version = exports.read_resource(plv8, resource)

  unless old_version
    return {status: "Error", message: "Resource #{resource.resourceType}/#{id} not exists"}

  if not old_version.meta  or not old_version.meta.versionId
    return {status: "Error", message: "Resource #{resource.resourceType}/#{id}, has broken old version #{JSON.stringify(old_version)}"}

  version_id = utils.uuid(plv8)

  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    request:
      method: 'PUT'
      url: resource.resourceType

  utils.exec plv8,
    update: sql.q(table_name)
    where: {id: id}
    values:
      version_id: version_id
      resource: sql.jsonb(resource)
      updated_at: sql.now

  utils.exec plv8,
    update: sql.q(hx_table_name)
    where: {id: id, version_id: old_version.meta.versionId}
    values: {valid_to: sql.now}

  utils.exec plv8,
    insert: sql.q(hx_table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      valid_from: sql.now
      valid_to: sql.infinity

  resource


exports.update_resource = update_resource
exports.update_resource.plv8_signature = ['json', 'json']

exports.delete_resource = (plv8, resource)->
  id = resource.id
  assert(id, 'resource.id')
  assert(resource.resourceType, 'resource.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  old_version = exports.read_resource(plv8, resource)

  unless old_version
    return {status: "Error", message: "Resource #{resource.resourceType}/#{id} not exists"}

  if not old_version.meta  or not old_version.meta.versionId
    return {status: "Error", message: "Resource #{resource.resourceType}/#{id}, has broken old version #{JSON.stringify(old_version)}"}

  resource = utils.copy(old_version)

  version_id = utils.uuid(plv8)

  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    request:
      method: 'DELETE'
      url: resource.resourceType

  utils.exec plv8,
    delete: sql.q(table_name)
    where: { id: id }

  utils.exec plv8,
    update: sql.q(hx_table_name)
    where: {id: id, version_id: old_version.meta.versionId}
    values: {valid_to: sql.now }

  utils.exec plv8,
    insert: sql.q(hx_table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      valid_from: sql.now
      valid_to: sql.now

  resource


exports.delete_resource.plv8_signature = ['json', 'json']

exports.history = (plv8, query)->
  id = query.id
  assert(id, 'query.id')
  assert(query.resourceType, 'query.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  resources = utils.exec( plv8,
    select: sql.raw('*')
    from:   sql.q(hx_table_name)
    where:  {id: query.id}
  ).map((x)-> JSON.parse(x.resource))

  bundle.history_bundle(resources)

exports.load = (plv8, bundle)->
  res = []
  for entry in bundle.entry when entry.resource
    resource = entry.resource
    if resource.id
      prev = read_resource(plv8, resource)
      unless prev.status == 'Error'
        res.push([resource.id, 'udpated'])
        update_resource(plv8, resource)
      else
        res.push([resource.id, 'created'])
        create_resource(plv8, resource)
    else
      res.push([resource.id, 'created'])
      create_resource(plv8, resource)
  res

# TODO: implement load bundle
# TODO: implement merge bundle
