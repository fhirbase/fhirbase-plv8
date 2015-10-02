outcome = require('../core/outcome')
xpath = require('./xpath')

noimpl = ->
  throw new Error('not implemented')

identity = (x)-> x

date_to_range = (x)->
  ["[#{x},#{x})"]

isObject = (x)->
  x != null and typeof x == 'object'

values = (obj)->
  res = []
  for k,v of obj
    if isObject(v)
      res = res.concat(values(v))
    else
      res.push(v)
  res


SEARCH_TYPES =
  boolean:
    token: noimpl
  code:
    token: identity
  date:
    date: date_to_range
  dateTime:
    date: noimpl
  instant:
    date: noimpl
  integer:
    number: noimpl
  string:
    string: identity
    token: noimpl
  uri:
    reference: noimpl
    uri: noimpl
  Address:
    string: values
  Annotation: null
  CodeableConcept:
    token: noimpl
  Coding:
    token: noimpl
  ContactPoint:
    token: noimpl
  Duration: null
  HumanName:
    string: values
  Identifier:
    token: noimpl
  Period:
    date: noimpl
  Quantity:
    number: noimpl
    quantity: noimpl
  Range: null
  Reference:
    reference: noimpl
  SampledData: null
  Timing:
    date: noimpl

is_valid_combination = ({elementType, searchType})->
  stypes = SEARCH_TYPES[elementType]
  unless stypes
    return [null, outcome.error(code: 'invalid', diagnostics: "Search for [#{elementType}] is not supported")]
  handler  = stypes[searchType]
  unless handler
    return [null, outcome.error(code: 'invalid', diagnostics: "Search for [#{elementType} #{searchType}] is not supported")]
  [handler]

exports.extract  = (resource, opts)->
  paths = opts.path

  [handler,error] = is_valid_combination(opts)
  return error if error

  res = []
  for v in xpath.get_in(resource, opts.path)
    res = res.concat(handler(v))
  res
