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
history = require('./history')
jsonpatch = require('../../node_modules/fast-json-patch/src/json-patch.js')

term = require('./terminology')

AFTER_HOOKS = {
  ValueSet:
    created: [term.fhir_valueset_after_changed]
    updated: [term.fhir_valueset_after_changed]
    patched: [term.fhir_valueset_after_changed]
    deleted: [term.fhir_valueset_after_deleted]
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
  text: {div: "<div>Storage for #{resourceType} does not exist</div>"}
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

_get_in = (obj, path)->
 cur = obj
 for step in path
   cur = cur[step] if cur
 cur

_build =  (mws, handler)->
  cur = handler
  for mw in mws.reverse()
    cur = mw[0](cur, mw[1])
  cur

wrap_ensure_table = (fn)->
  (plv8, query)->
    resourceType = query.resourceType || (query.resource && query.resource.resourceType )
    table_name = namings.table_name(plv8, resourceType)
    hx_table_name = namings.history_table_name(plv8, resourceType)
    unless pg_meta.table_exists(plv8, table_name)
      return table_not_exists(resourceType)
    else
      query.table_name = table_name
      query.hx_table_name = hx_table_name
      fn(plv8, query)

wrap_required_attributes = (fn, attrs)->
  (plv8, query)->
    issue = []
    for attr in attrs
      unless _get_in(query, attr)
        issue.push(severity: 'error', code: 'structure', diagnostics: "expected attribute #{attr}")
    if issue.length > 0
      return {resourceType: "OperationOutcome", issue: issue }
    fn(plv8, query)

wrap_hooks = (fn, phase)->
  (plv8, query)->
    result = fn(plv8, query)
    hooks = (AFTER_HOOKS[result.resourceType] && AFTER_HOOKS[result.resourceType][phase])
    for hook in (hooks || []) when hook
      hook(plv8, result)
    return result

wrap_if_not_exists = (fn)->
  (plv8, query)->
    resourceType = query.resource.resourceType
    if query.ifNoneExist
      result = search.fhir_search(plv8, {resourceType: resourceType, queryString: query.ifNoneExist})
      if result.entry.length == 1
        return result.entry[0].resource
      else if result.entry.length > 1
        return outcome.non_selective(query.ifNoneExist)
    fn(plv8, query)

wrap_ensure_not_exists = (fn)->
  (plv8, query)->
    resource = query.resource
    if resource.id
      res = utils.exec plv8,
        select: sql.raw('id')
        from: sql.q(query.table_name)
        where: {id: resource.id}
      if res.length > 0
        return outcome.bad_request('resource with given id already exists')
    fn(plv8, query)

wrap_postprocess = (fn)->
  (plv8, query)->
    res = fn(plv8, query)
    helpers.postprocess_resource(res)

fhir_create_resource = _build [
    [wrap_required_attributes, [['resource'], ['resource', 'resourceType']]]
    [wrap_ensure_table]
    [wrap_if_not_exists]
    [wrap_ensure_not_exists]
    [wrap_hooks, 'created']
    [wrap_postprocess]
  ], (plv8, query)->


  resource = query.resource

  if resource.id and not query.allowId
    return outcome.error(
      code: '400'
      diagnostics: '''
      id is not allowed, use update operation to create with predefined id
      '''
      extension: [{url: 'http-status-code', valueString: '400'}]
    )

  id = resource.id || utils.uuid(plv8)
  resource.id = id
  version_id = utils.uuid(plv8)

  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    extension: [{
      url: 'fhir-request-method',
      valueString: 'POST'
    }, {
      url: 'fhir-request-uri',
      valueUri: resource.resourceType
    }]

  utils.exec plv8,
    insert: sql.q(query.table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      created_at: sql.now
      updated_at: sql.now

  utils.exec plv8,
    insert: sql.q(query.hx_table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      valid_from: sql.now
      valid_to: sql.infinity

  resource

exports.fhir_create_resource = fhir_create_resource
exports.fhir_create_resource.plv8_signature = ['json', 'json']

resource_is_deleted = (plv8, query)->
  assert(query.id, 'query.id')
  assert(query.resourceType, 'query.resourceType')
  hx_table_name = namings.history_table_name(plv8, query.resourceType)
  # TODO??

fhir_read_resource = _build [
    [wrap_required_attributes, [['id'], ['resourceType']]]
    [wrap_ensure_table]
    [wrap_postprocess]
  ],(plv8, query)->

  res = utils.exec plv8,
    select: ':*'
    from: sql.q(query.table_name)
    where: { id: query.id }

  row = res[0]

  unless row
    deletionHistory = history.fhir_resource_history(plv8, {
      id: query.id, resourceType: query.resourceType
    }).entry.filter((entry) -> entry.request.method == 'DELETE')

    if deletionHistory.length > 0
      return outcome.version_deleted(query.id, query.versionId) #this means that the resource is deleted (#65)

    return outcome.not_found(query.id)

  compat.parse(plv8, row.resource)

exports.fhir_read_resource = fhir_read_resource
exports.fhir_read_resource.plv8_signature = ['json', 'json']

exports.fhir_vread_resource = _build [
    [wrap_required_attributes, [['id'], ['resourceType'], ['versionId']]]
    [wrap_ensure_table]
    [wrap_postprocess]
  ], (plv8, query)->

  res = utils.exec plv8,
    select: ':*'
    from: sql.q(query.hx_table_name)
    where: {id: query.id, version_id: query.versionId}

  row = res[0]

  unless row
    return outcome.version_not_found(query.id, query.versionId)

  resource = compat.parse(plv8, row.resource)
  requestMethod = resource.meta.extension.filter(
    (e) -> e.url == 'fhir-request-method'
  )[0].valueString

  if requestMethod == 'DELETE'
    outcome.version_deleted(query.id, query.versionId)
  else
    resource

exports.fhir_vread_resource.plv8_signature = ['json', 'json']

fhir_update_resource = _build [
    [wrap_required_attributes, [['resource']]]
    [wrap_ensure_table]
    [wrap_postprocess]
    [wrap_hooks, 'updated']
  ], (plv8, query)->

  resource = query.resource

  old_version = null
  id = null

  if query.queryString
    result = search.fhir_search(plv8, {resourceType: resource.resourceType, queryString: query.queryString})
    if result.entry.length == 0
      return fhir_create_resource(plv8, allowId: true, resource: resource)
    else if result.entry.length == 1
      old_version = result.entry[0].resource
      resource.id = old_version.id
      id = resource.id
    else if result.entry.length > 1
      return outcome.non_selective(query.ifNoneExist)
  else
    unless resource.id
      return outcome.bad_request("Could not update resource without id")

    unless resource.resourceType
      return outcome.bad_request("Could not update resource without resourceType")

    res = utils.exec plv8,
      select: sql.raw('*')
      from: sql.q(query.table_name)
      where: {id: resource.id}

    if res.length == 0
      query.allowId = true
      return fhir_create_resource(plv8, query)
    else if res.length == 1
      old_version = compat.parse(plv8, res[0].resource)
      id = resource.id
    else
      return outcome.bad_request('Unexpected many resources for one id')

  if old_version.resourceType == 'OperationOutcome'
    return old_version

  throw new Error("Unexpected behavior, no id") unless id

  if query.ifMatch && old_version.meta.versionId != query.ifMatch
    return outcome.conflict("Newer than [#{query.ifMatch}] version available [#{old_version.meta.versionId}]")

  version_id = utils.uuid(plv8)

  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    extension: [{
      url: 'fhir-request-method',
      valueString: 'PUT'
    }, {
      url: 'fhir-request-uri',
      valueUri: resource.resourceType
    }]

  utils.exec plv8,
    update: sql.q(query.table_name)
    where: {id: id}
    values:
      version_id: version_id
      resource: sql.jsonb(resource)
      updated_at: sql.now

  utils.exec plv8,
    update: sql.q(query.hx_table_name)
    where: {id: id, version_id: old_version.meta.versionId}
    values: {valid_to: sql.now}

  utils.exec plv8,
    insert: sql.q(query.hx_table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      valid_from: sql.now
      valid_to: sql.infinity

  resource


exports.fhir_update_resource = fhir_update_resource
exports.fhir_update_resource.plv8_signature = ['json', 'json']

fhir_patch_resource = _build [
    [wrap_required_attributes, [['resource']]]
    [wrap_ensure_table]
    [wrap_postprocess]
    [wrap_hooks, 'patched']
  ], (plv8, query)->
    resource = fhir_read_resource(plv8, {
      resourceType: query.resource.resourceType, id: query.resource.id
    })

    jsonpatch.apply(resource, query.patch)

    old_version = null
    id = null

    if query.queryString
      result = search.fhir_search(plv8, {resourceType: resource.resourceType, queryString: query.queryString})
      if result.entry.length == 0
        return fhir_create_resource(plv8, allowId: true, resource: resource)
      else if result.entry.length == 1
        old_version = result.entry[0].resource
        resource.id = old_version.id
        id = resource.id
      else if result.entry.length > 1
        return outcome.non_selective(query.ifNoneExist)
    else
      unless resource.id
        return outcome.bad_request("Could not patch resource without id")

      unless resource.resourceType
        return outcome.bad_request("Could not patch resource without resourceType")

      res = utils.exec plv8,
        select: sql.raw('*')
        from: sql.q(query.table_name)
        where: {id: resource.id}

      if res.length == 0
        query.allowId = true
        return fhir_create_resource(plv8, query)
      else if res.length == 1
        old_version = compat.parse(plv8, res[0].resource)
        id = resource.id
      else
        return outcome.bad_request('Unexpected many resources for one id')

    if old_version.resourceType == 'OperationOutcome'
      return old_version

    throw new Error("Unexpected behavior, no id") unless id

    if query.ifMatch && old_version.meta.versionId != query.ifMatch
      return outcome.conflict("Newer than [#{query.ifMatch}] version available [#{old_version.meta.versionId}]")

    version_id = utils.uuid(plv8)

    ensure_meta resource,
      versionId: version_id
      lastUpdated: new Date()
      extension: [{
        url: 'fhir-request-method',
        valueString: 'PUT'
      }, {
        url: 'fhir-request-uri',
        valueUri: resource.resourceType
      }]

    utils.exec plv8,
      update: sql.q(query.table_name)
      where: {id: id}
      values:
        version_id: version_id
        resource: sql.jsonb(resource)
        updated_at: sql.now

    utils.exec plv8,
      update: sql.q(query.hx_table_name)
      where: {id: id, version_id: old_version.meta.versionId}
      values: {valid_to: sql.now}

    utils.exec plv8,
      insert: sql.q(query.hx_table_name)
      values:
        id: id
        version_id: version_id
        resource: sql.jsonb(resource)
        valid_from: sql.now
        valid_to: sql.infinity

    resource

exports.fhir_patch_resource = fhir_patch_resource
exports.fhir_patch_resource.plv8_signature = ['json', 'json']

exports.fhir_delete_resource = _build [
    [wrap_required_attributes, [['id'], ['resourceType']]]
    [wrap_ensure_table]
    [wrap_postprocess]
    [wrap_hooks, 'deleted']
  ], (plv8, query)->

  id = query.id
  old_version = exports.fhir_read_resource(plv8, query)

  unless old_version
    return outcome.not_found(query.id)

  if old_version.resourceType == 'OperationOutcome'
    return old_version

  if not old_version.meta  or not old_version.meta.versionId
    return outcome.bad_request(
      "Resource #{query.resourceType}/#{query.id}, " +
        "has broken old version #{JSON.stringify(old_version)}"
    )

  resource = utils.copy(old_version)

  version_id = utils.uuid(plv8)

  ensure_meta resource,
    versionId: version_id
    lastUpdated: new Date()
    extension: [{
      url: 'fhir-request-method',
      valueString: 'DELETE'
    }, {
      url: 'fhir-request-uri',
      valueUri: query.resourceType
    }]

  utils.exec plv8,
    delete: sql.q(query.table_name)
    where: { id: id }

  utils.exec plv8,
    update: sql.q(query.hx_table_name)
    where: {id: id, version_id: old_version.meta.versionId}
    values: {valid_to: sql.now }

  utils.exec plv8,
    insert: sql.q(query.hx_table_name)
    values:
      id: id
      version_id: version_id
      resource: sql.jsonb(resource)
      valid_from: sql.now
      valid_to: sql.now

  resource

exports.fhir_delete_resource.plv8_signature = ['json', 'json']

exports.fhir_terminate_resource = _build [
   [wrap_required_attributes, [['id'], ['resourceType']]]
   [wrap_ensure_table]
  ],(plv8, query)->

  res = utils.exec plv8,
    delete: sql.q(query.hx_table_name)
    where: { id: query.id }
    returning: ':*'

  curr = utils.exec plv8,
    delete: sql.q(query.table_name)
    where: { id: query.id }
    returning: ':*'

  res = res.concat(curr)
  res.map((x)-> x.resource)

exports.fhir_terminate_resource.plv8_signature = ['json', 'json']

exports.fhir_load = (plv8, bundle)->
  res = []
  for entry in bundle.entry when entry.resource
    resource = entry.resource
    unless resource.resourceType == 'Conformance'
      if resource.id
        prev = read_resource(plv8, resource)
        if outcome.is_not_found(prev)
          fhir_create_resource(plv8, allowId: true, resource: resource)
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
