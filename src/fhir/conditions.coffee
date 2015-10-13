lang = require('../lang')

TODO = ()->
  throw new Error("Not impl.")

string_ilike = (opts, value)->
  call =
    call: extract_fn(opts.searchType, opts.array)
    args: [':resource::json', JSON.stringify(opts.path), opts.elementType]
    cast: 'text'
  [':ilike', call, value]

TABLE =
  boolean:
    token: TODO
  code:
    token: TODO
  date:
    date:
      eq: TODO
      ne: TODO
      gt: TODO
      lt: TODO
      ge: TODO
      le: TODO
      sa: TODO
      eb: TODO
      ap: TODO
  dateTime:
    date:
      eq: TODO
      ne: TODO
      gt: TODO
      lt: TODO
      ge: TODO
      le: TODO
      sa: TODO
      eb: TODO
      ap: TODO
  instant:
    date: TODO
  integer:
    number: TODO
  decimal:
    number: TODO
  string:
    string: TODO
    token: TODO
  uri:
    reference: TODO
    uri: TODO
  Period:
    date: TODO
  Address:
    string: TODO
  Annotation: null
  CodeableConcept:
    token: TODO
  Coding:
    token: TODO
  ContactPoint:
    token: TODO
  HumanName:
    string:
      sw: (opts)-> string_ilike(opts, "%^^#{opts.value}%")
      co: (opts)-> string_ilike(opts, "%#{opts.value}%")
  Identifier:
    token: TODO
  Quantity:
    number: TODO
    quantity: TODO
  Duration: null
  Range: null
  Reference:
    reference: TODO
  SampledData: null
  Timing:
    date: TODO

extract_fn = (resultType, array)->
  res = []
  res.push('fhir.extract_as_')
  res.push(resultType.toLowerCase())
  if array
    res.push('_array')
  res.join('')

condition = (opts)->
  handler = TABLE[opts.elementType]
  throw new Error("#{opts.elementType} is not suported") unless handler
  handler = handler[opts.searchType]
  throw new Error("#{opts.elementType} #{opts.searchType} is not suported") unless handler
  handler = handler[opts.operator]
  throw new Error("Operator #{opts.operator} in #{opts.elementType} #{opts.searchType} is not suported") unless handler
  handler(opts)

exports.condition = condition

walk = (expr)->
  if lang.isArray(expr)
    expr.map((x)-> walk(x))
  else if lang.isObject(expr)
    condition(expr)
  else
    if expr == 'OR'
      ':OR'
    else if expr == 'AND'
      ':AND'
    else
      expr

exports.walk = walk
