crud = require('./crud')
search = require('./search')

RES_TYPE_RE = "([A-Za-z]+)"
ID_RE = "([A-Za-z0-9\\-]+)"
QUERY_STRING_RE = "([A-Za-z0-9 &=-]+)"

strip = (obj)->
  res = {}
  for k,v of obj when v
    res[k] = v
  res


HANDLERS = [
  {
    name: 'Instance'
    test: new RegExp("^/#{RES_TYPE_RE}/#{ID_RE}$")
    GET: (match, entry)->
      type: 'read'
      id: match[2]
      resourceType: match[1]

    PUT: (match, entry)->
      strip
        type: 'update'
        queryString: entry.request.queryString
        id: match[2]
        resourceType: match[1]
        resource: entry.resource

    DELETE: (match, entry)->
      type: 'delete'
      id: match[2]
      resourceType: match[1]
  }
  {
    name: 'Revision'
    test: new RegExp("^/#{RES_TYPE_RE}/#{ID_RE}/_history/#{ID_RE}$")
    GET: (match, entry)->
      type: 'vread'
      id: match[2]
      resourceType: match[1]
      versionId: match[3]
  }
  {
    name: 'Instance History'
    test: new RegExp("^/#{RES_TYPE_RE}/#{ID_RE}/_history$")
    GET: (match, entry)->
      type: 'history'
      resourceType: match[1]
      id: match[2]
  }
  {
    name: 'Resource Type History'
    test: new RegExp("^/?#{RES_TYPE_RE}/?$")
    POST: (match, entry)->
      strip
        type: 'create'
        ifNoneExist: entry.request.ifNoneExist
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
  {
    test: new RegExp("^/#{RES_TYPE_RE}/?\\?#{QUERY_STRING_RE}$")
    GET: (match, entry)->
      type: 'search'
      resourceType: match[1]
      queryString: match[2]
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
  plan = bundle.entry.map (entry) ->
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

  plan.sort((a, b)->
    # Transaction should processed in order (DELETE, POST, PUT, GET).

    number = (action)->
      switch action.type
        when 'delete' then 1 # DELETE
        when 'create' then 2 # POST
        when 'update' then 3 # PUT
        when 'read' then 4 # GET
        when 'vread' then 4 # GET
        when 'search' then 4 # GET

    aa = number(a)
    bb = number(b)

    if aa < bb
      return -1

    if aa > bb
      return 1

    0
  )

exports.makePlan = makePlan

executePlan = (plv8, plan) ->
  plan.map (action) ->
    switch action.type
      when "create"
        crud.fhir_create_resource(plv8, action)
      when "update"
        action.resource.id = action.resource.id || (!action.queryString && action.id)
        crud.fhir_update_resource(plv8, action)
      when "delete"
        crud.fhir_delete_resource(plv8, {id: action.id, resourceType: action.resourceType})
      when "read"
        crud.fhir_read_resource(plv8, {id: action.id, resourceType: action.resourceType})
      when "vread"
        crud.fhir_vread_resource(plv8, {id: action.id, resourceType: action.resourceType, versionId: action.versionId})
      when "search"
        search.fhir_search(plv8,
          resourceType: action.resourceType, queryString: action.queryString)
      else
        "request.type is not supported - \n#{JSON.stringify(action)}"

exports.executePlan = executePlan

execute = (plv8, bundle, strictMode) ->
  plan = makePlan(bundle)

  if strictMode
    errors = plan.filter (i) -> i.type == 'error'

    if errors.length > 0
      return {
        resourceType: "OperationOutcome"
        message: "There were incorrect requests within transaction. #{JSON.stringify(errors)}"
      }

  result = executePlan(plv8, plan)

  resourceType: "Bundle"
  type: 'transaction-response'
  entry: result

exports.execute = execute


exports.fhir_transaction = (plv8, bundle)-> execute(plv8, bundle, true)

exports.fhir_transaction.plv8_signature = ['json', 'json']
