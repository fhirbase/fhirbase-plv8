crud = require('../core/crud.coffee')

RES_TYPE_RE = "([A-Za-z]+)"
ID_RE = "([A-Za-z0-9\\-]+)"

HANDLERS = [
  {
    name: 'Instance'
    test: new RegExp("^/#{RES_TYPE_RE}/#{ID_RE}$")
    GET: (match, entry)->
      type: 'read'
      resourceId: match[2]
      resourceType: match[1]

    PUT: (match, entry)->
      type: 'update'
      resourceId: match[2]
      resourceType: match[1]
      resource: entry.resource

    DELETE: (match, entry)->
      type: 'delete'
      resourceId: match[2]
      resourceType: match[1]
  }
  {
    name: 'Revision'
    test: new RegExp("^/#{RES_TYPE_RE}/#{ID_RE}/_history/#{ID_RE}$")
    GET: (match, entry)->
      type: 'vread'
      resourceId: match[2]
      resourceType: match[1]
      versionId: match[3]
  }
  {
    name: 'Instance History'
    test: new RegExp("^/#{RES_TYPE_RE}/#{ID_RE}/_history$")
    GET: (match, entry)->
      type: 'history'
      resourceType: match[1]
      resourceId: match[2]
  }
  {
    name: 'Resource Type History'
    test: new RegExp("^/#{RES_TYPE_RE}$")
    POST: (match, entry)->
      type: 'create'
      resource: entry.resource
      resourceType: match[1]
  }
  {
    name: 'History'
    test: new RegExp("^/#{RES_TYPE_RE}/_history$")
    GET: (match, entry)->
      type: 'history'
      resourceType: match[1]
  }
  {
    test: new RegExp("^/_history$")
    GET: (match, entry)->
      type: 'history'
  }
]

# TODO:
# - conditional update
# - conditional delete

find = (coll, pred)->
  for x in coll
    return x if pred(x)
  null

makePlan = (bundle) ->
  bundle.entry.map (entry) ->
    url = entry.request.url
    method = entry.request.method

    handler = find HANDLERS, (h)-> url.match(h.test) && h[method]

    if handler and handler[method]
      match = url.match(handler.test)
      action = handler[method]
      action(match, entry)
    else
      type: 'error'
      message: "Cannot determine action for request #{method} #{url}"

exports.makePlan = makePlan

executePlan = (plv8, plan) ->
  plan.map (action) ->
    switch action.type
      when "create"
        crud.fhir_create_resource(plv8, action.resource)
      when "update"
        resource = action.resource
        resource.resourceType = action.resourceType
        resource.id = action.resourceId

        crud.fhir_update_resource(plv8, resource)
      when "delete"
        crud.fhir_delete_resource(plv8, {id: action.resourceId, resourceType: action.resourceType})
      when "read"
        crud.fhir_read_resource(plv8, {id: action.resourceId, resourceType: action.resourceType})
      when "vread"
        crud.fhir_vread_resource(plv8, {id: action.resourceId, resourceType: action.resourceType, versionId: action.versionId})
      else
        "TODO: return operation outcome here!\n#{action.message}"
exports.executePlan = executePlan

execute = (plv8, bundle, strictMode) ->
  plan = makePlan(bundle)

  if strictMode
    errors = plan.filter (i) -> i.type == 'error'

    if errors.length > 0
      return {
        resourceType: "OperationOutcome"
        message: "TODO: make correct operation outcome here!\nThere were incorrect requests within transaction"
      }

  result = executePlan(plv8, plan)

  resourceType: "Bundle"
  entry: result

exports.execute = execute


exports.fhir_transaction = (plv8, bundle)-> execute(plv8, bundle, true)

exports.fhir_transaction.plv8_signature = ['json', 'json']
