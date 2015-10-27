sql = require('../honey')
lang = require('../lang')
xpath = require('./xpath')

exports.plv8_schema = "fhir"

TODO = -> throw new Error("TODO")

exports.extract_as_token = (plv8, resource, path, element_type)->
  res = []
  data = xpath.get_in(resource, [path])
  if element_type == 'boolean' || element_type == 'code' || element_type == 'string'
    str.toString() for str in data 
  else if element_type == 'Identifier' or element_type == 'ContactPoint'
    for coding in data 
        res.push(coding.value)
        res.push("#{coding.system}|#{coding.value}")
    res
  else if element_type == 'Coding'
    for coding in data 
        res.push(coding.code)
        res.push("#{coding.system}|#{coding.code}")
    res
  else if element_type == 'CodeableConcept'
    for concept in data
      for coding in (concept.coding || [])
        res.push(coding.code)
        res.push("#{coding.system}|#{coding.code}")
    res
  else if element_type == 'Reference'
    for ref in data
      res.push(ref.reference)
    res
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
