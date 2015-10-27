sql = require('../honey')
xpath = require('./xpath')

exports.plv8_schema = "fhir"

TODO = -> throw new Error("TODO")

exports.extract_as_reference = (plv8, resource, path, element_type)->
  if element_type == 'Reference'
    xpath.get_in(resource, [path]).map((x)-> x.reference)
  else
    throw new Error("extract_as_reference: Not implemented for #{element_type}")

exports.extract_as_reference.plv8_signature = ['json', 'json', 'text', 'text[]']


reference_eq = (tbl, meta, value)->
  ["$&&"
    ['$cast'
      ['$fhir.extract_as_reference'
        ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
        ['$json', meta.path]
        meta.elementType]
        ":text[]"]
    ['$cast', ['$array', value.value], ":text[]"]
    value]


OPERATORS =
  eq: reference_eq

SUPPORTED_TYPES = [
 'Reference'
]

handle = (tbl, meta, value)->
  unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
    throw new Error("Reference Search: unsuported type #{JSON.stringify(meta)}")

  op = OPERATORS[meta.operator]

  unless op
    throw new Error("Reference Search: Unsupported operator #{JSON.stringify(meta)}")

  op(tbl, meta, value)

exports.handle = handle
