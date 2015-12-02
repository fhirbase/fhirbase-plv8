namings = require('../core/namings')
pg_meta = require('../core/pg_meta')
utils = require('../core/utils')
sql = require('../honey')
bundle = require('./bundle')
helpers = require('./search_helpers')
outcome = require('./outcome')
date = require('./date')
search = require('./search')
compat = require('../compat')

term = require('./terminology')

AFTER_HOOKS = {
  ValueSet: [term.fhir_valueset_after_changed]
}

validate_create_resource = (resource)->
  unless resource.resourceType
    resourceType: "OperationOutcome"
    text:{div: "<div>Resource should have [resourceType] element</div>"}
    issue: [
      severity: 'error'
      code: 'structure'
    ]

table_not_exists = (resourceType)->
  resourceType: "OperationOutcome"
  text: {div: "<div>Storage for #{resourceType} not exists</div>"}
  issue: [
    severity: 'error'
    code: 'not-supported'
  ]

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
    return [null, null, table_not_exists(resourceType)]
  else
    [table_name, hx_table_name, null]

fhir_create_resource = (plv8, query)->
  resource = query.resource
  throw new Error("expected arguments {resource: ...}") unless resource
  errors = validate_create_resource(resource)
  return errors if errors


  [table_name, hx_table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  if query.ifNotExist
    result = search.fhir_search(plv8, {resourceType: resource.resourceType, queryString: query.ifNotExist})
    if result.entry.length == 1
      return result.entry[0].resource
    else if result.entry.length > 1
      return outcome.non_selective(query.ifNotExist)

  # create or update
  if resource.id
    q =
      select: sql.raw('id')
      from: sql.q(hx_table_name)
      where: {id: resource.id}

    res = utils.exec(plv8,q)
    row = res[0]
    throw new Error("resource with given id already exist ") if row

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

  hooks = AFTER_HOOKS[resource.resourceType]
  for hook in (hooks || []) when hook
    hook(plv8, resource)

  helpers.postprocess_resource(resource)

exports.fhir_create_resource = fhir_create_resource
exports.fhir_create_resource.plv8_signature = ['json', 'json']

resource_is_deleted = (plv8, query)->
  assert(query.id, 'query.id')
  assert(query.resourceType, 'query.resourceType')
  hx_table_name = namings.history_table_name(plv8, query.resourceType)


fhir_read_resource = (plv8, query)->
  assert(query.id, 'query.id')
  assert(query.resourceType, 'query.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  res = utils.exec(plv8, select: sql.raw('*'), from: sql.q(table_name), where: { id: query.id })
  row = res[0]
  unless row
    return outcome.not_found(query.id)

  helpers.postprocess_resource(compat.parse(plv8, row.resource))

exports.fhir_read_resource = fhir_read_resource
exports.fhir_read_resource.plv8_signature = ['json', 'json']

exports.fhir_vread_resource = (plv8, query)->
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
    return outcome.not_found(query.id)

  helpers.postprocess_resource(compat.parse(plv8, row.resource))

exports.fhir_vread_resource.plv8_signature = ['json', 'json']

fhir_update_resource = (plv8, query)->
  resource = query.resource
  throw new Error("expected arguments {resource: ...}") unless resource

  [table_name, hx_table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  if query.queryString
    result = search.fhir_search(plv8, {resourceType: resource.resourceType, queryString: query.queryString})
    if result.entry.length == 0
      return fhir_create_resource(plv8, resource: resource)
    else if result.entry.length == 1
      old_version = result.entry[0].resource
      resource.id = old_version.id
      id = resource.id
    else if result.entry.length > 1
      return outcome.non_selective(query.ifNotExist)
  else
    q =
      select: sql.raw('*')
      from: sql.q(hx_table_name)
      where: {id: resource.id}
    res = utils.exec(plv8,q)
    row = res[0]
    unless row
      return fhir_create_resource(plv8, query)

    id = resource.id
    assert(id, 'resource.id')
    assert(resource.resourceType, 'resource.resourceType')
    old_version = exports.fhir_read_resource(plv8, resource)

  if old_version.resourceType == 'OperationOutcome'
    return old_version

  throw new Error("Unexpected behavior, no id") unless id

  if query.ifMatch && old_version.meta.versionId != query.ifMatch
    return outcome.conflict("Newer then [#{query.ifMatch}] version available [#{old_version.meta.versionId}]")

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

  hooks = AFTER_HOOKS[resource.resourceType]
  for hook in (hooks || []) when hook
    hook(plv8, resource)

  helpers.postprocess_resource(resource)


exports.fhir_update_resource = fhir_update_resource
exports.fhir_update_resource.plv8_signature = ['json', 'json']

exports.fhir_delete_resource = (plv8, resource)->
  id = resource.id
  assert(id, 'resource.id')
  assert(resource.resourceType, 'resource.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  old_version = exports.fhir_read_resource(plv8, resource)

  unless old_version
    return outcome.not_found(query.id)

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

  hooks = AFTER_HOOKS[resource.resourceType]
  for hook in (hooks || []) when hook
    hook(plv8, resource)

  helpers.postprocess_resource(resource)

exports.fhir_delete_resource.plv8_signature = ['json', 'json']

exports.fhir_terminate_resource = (plv8, resource)->
  id = resource.id
  assert(id, 'resource.id')
  assert(resource.resourceType, 'resource.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, resource.resourceType)
  return errors if errors

  res = []
  res.push utils.exec plv8,
    delete: sql.q(table_name)
    where: { id: id }
    returning: '*'

  res.push utils.exec plv8,
    delete: sql.q(hx_table_name)
    where: { id: id }
    returning: '*'

  res

exports.fhir_terminate_resource.plv8_signature = ['json', 'json']

exports.fhir_load = (plv8, bundle)->
  res = []
  for entry in bundle.entry when entry.resource
    resource = entry.resource
    unless resource.resourceType == 'Conformance'
      if resource.id
        prev = read_resource(plv8, resource)
        if outcome.is_not_found(prev)
          fhir_create_resource(plv8, resource)
        else if prev.id == resource.id
          res.push([resource.id, 'udpated'])
          fhir_update_resource(plv8, resource)
        else
          throw new Error("Load problem #{JSON.stringify(prev)}")
      else
        res.push([resource.id, 'created'])
        fhir_create_resource(plv8, resource)
  res

exports.fhir_load.plv8_signature = ['json', 'json']

# TODO: implement load bundle
# TODO: implement merge bundle
