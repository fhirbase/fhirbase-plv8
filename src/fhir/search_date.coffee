date = require('./date')
xpath = require('./xpath')

exports.plv8_schema = "fhir"

SUPPORTED_TYPES = [
 'date'
 'dateTime'
 'instant'
 'Period'
 'Timing'
]

str = (x)-> x.toString()

exports.extract_as_daterange = (plv8, resource, path, element_type)->
  if ['date'].indexOf(element_type) > -1
    value = xpath.get_in(resource, [path]).map(str)
    date.to_range(value) if value
  else
    throw new Error("extract_as_token: Not implemented for #{element_type}")

exports.extract_as_daterange.plv8_signature = ['json', 'json', 'text', 'tstzrange']

overlap_expr = (tbl, meta, value)->
  value = value.value
  range = if meta.operator == 'lt' || meta.operator == 'le'
    ['$tstzrange', '-infinity', date.to_upper_date(value)]
  else if meta.operator == 'gt' || meta.operator == 'ge'
    ['$tstzrange', date.to_lower_date(value), 'infinity']
  else if meta.operator == 'eq'
    ['$tstzrange', date.to_lower_date(value), date.to_upper_date(value)]
  else
    throw new  Error('Unhandled')

  ["$&&"
    ['$cast'
      ['$fhir.extract_as_daterange'
        ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
        ['$json', meta.path]
        meta.elementType]
        "tstzrange"]
    range]

TODO = -> throw new Error("TODO")

OPERATORS =
  eq: overlap_expr
  gt: overlap_expr
  ge: overlap_expr
  lt: overlap_expr
  le: overlap_expr
  ne: TODO
  sa: TODO
  eb: TODO
  ap: TODO

handle = (tbl, meta, value)->
  unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
    throw new Error("Date Search: unsuported type #{JSON.stringify(meta)}")

  op = OPERATORS[meta.operator]

  unless op
    throw new Error("Date Search: Unsupported operator #{JSON.stringify(meta)}")

  op(tbl, meta, value)

exports.handle = handle
