lang = require('../lang')
sql = require('../honey')
xpath = require('./xpath')

exports.plv8_schema = "fhir"

TODO = -> throw new Error("TODO")
exports.extract_as_string = (plv8, resource, path, element_type)->
  obj = xpath.get_in(resource, [path])
  ("^^#{v}$$" for v in lang.values(obj)).join(" ")

exports.extract_as_string.plv8_signature = ['json', 'json', 'text', 'text']

normalize_string_value = (x)->
  x && x.trim().toLowerCase()

ilike_expr = (tbl, meta, value)->
  ["$ilike"
    ['$cast'
      ['$fhir.extract_as_string'
        ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
        ['$json', meta.path]
        meta.elementType]
        "text"]
    value]


OPERATORS =
  eq: (tbl, meta, value)-> ilike_expr(tbl, meta, "%^^#{normalize_string_value(value.value)}$$%")
  sw: (tbl, meta, value)-> ilike_expr(tbl, meta, "%^^#{normalize_string_value(value.value)}%")
  ew: (tbl, meta, value)-> ilike_expr(tbl, meta, "%#{normalize_string_value(value.value)}$$%")
  co: (tbl, meta, value)-> ilike_expr(tbl, meta, "%#{normalize_string_value(value.value)}%")

SUPPORTED_TYPES = [
 'Address'
 'ContactPoint'
 'HumanName'
 'string'
]

handle = (tbl, meta, value)->
  unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
    throw new Error("String Search: unsuported type #{JSON.stringify(meta)}")

  op = OPERATORS[meta.operator]

  unless op
    throw new Error("String Search: Unsupported operator #{JSON.stringify(meta)}")

  op(tbl, meta, value)

exports.handle = handle
