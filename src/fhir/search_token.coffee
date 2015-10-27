sql = require('../honey')
xpath = require('./xpath')

exports.plv8_schema = "fhir"

TODO = -> throw new Error("TODO")

str = (x)-> x.toString()

exports.extract_as_token = (plv8, resource, path, element_type)->
  if ['boolean'].indexOf(element_type) > -1
    xpath.get_in(resource, [path]).map(str)
  else
    throw new Error("extract_as_token: Not implemented for #{element_type}")

exports.extract_as_token.plv8_signature = ['json', 'json', 'text', 'text[]']

token_eq = (tbl, meta, value)->
  ["$&&"
    ['$cast'
      ['$fhir.extract_as_token'
        ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
        ['$json', meta.path]
        meta.elementType]
        ":text[]"]
    ['$cast', ['$array', value.value], ":text[]"]
    value]


OPERATORS =
  eq: token_eq

SUPPORTED_TYPES = [
 'boolean'
 'code'
 'string'
 'CodeableConcept'
 'Coding'
 'ContactPoint'
 'Identifier'
 'Reference'
]

handle = (tbl, meta, value)->
  unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
    throw new Error("Token Search: unsuported type #{JSON.stringify(meta)}")

  op = OPERATORS[meta.operator]

  unless op
    throw new Error("Token Search: Unsupported operator #{JSON.stringify(meta)}")

  op(tbl, meta, value)

exports.handle = handle
