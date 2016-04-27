namings = require('../core/namings')
pg_meta = require('../core/pg_meta')
utils = require('../core/utils')
sql = require('../honey')
compat = require('../compat')
bundle = require('./bundle')
outcome = require('./outcome')
date = require('./date')

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

exports.fhir_resource_history = (plv8, query)->
  id = query.id
  assert(id, 'query.id')
  assert(query.resourceType, 'query.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  [params, errors] = parse_history_params(query.queryString || '')
  return errors if errors

  hsql =
    select: sql.raw('*')
    from:   sql.q(hx_table_name)
    where:  {id: query.id}
    order: [['$raw', '"valid_from" DESC']]

  if params._count
    hsql.limit = params._count

  if params._since
    hsql.where = ['$ge', ':valid_from', params._since]

  if params._before
    hsql.where = ['$le', ':valid_from', params._before]

  resources = utils.exec(plv8, hsql)
    .map((x)-> compat.parse(plv8, x.resource))

  bundle.history_bundle(resources)

exports.fhir_resource_history.plv8_signature = ['json', 'json']

parse_history_params = (queryString)->
  parsers =
    _since: date.to_lower_date
    _count: parseInt
    _before: date.to_lower_date

  reduce_fn = (acc, [k,v])->
    parser = parsers[k]
    if parser
      acc[k] = parser(v)
      acc
    else
      acc

  params = queryString
    .split('&')
    .map((x)-> x.split('='))
    .reduce(reduce_fn, {})

  [params, null]

exports.parse_history_params = parse_history_params

exports.fhir_resource_type_history = (plv8, query)->
  assert(query.resourceType, 'query.resourceType')

  [table_name, hx_table_name, errors] = ensure_table(plv8, query.resourceType)
  return errors if errors

  [params, errors] = parse_history_params(query.queryString || '')
  return errors if errors

  hsql =
    select: sql.raw('*')
    from:   sql.q(hx_table_name)
    order: [['$raw', '"valid_from" DESC']]

  if params._count
    hsql.limit = params._count

  if params._since
    hsql.where = ['$ge', ':valid_from', params._since]

  if params._before
    hsql.where = ['$le', ':valid_from', params._before]

  resources = utils.exec( plv8, hsql)
    .map((x)-> compat.parse(plv8, x.resource))

  bundle.history_bundle(resources)

exports.fhir_resource_type_history.plv8_signature = ['json', 'json']
