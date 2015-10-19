lang = require('../lang')
date = require('./date')

TODO = ()->
  throw new Error("Not impl.")

string_ilike = (opts, value)->
  call =
    call: extract_fn(opts.searchType, opts.array)
    args: [':resource::json', JSON.stringify(opts.path), opts.elementType]
    cast: 'text'
  [':ilike', call, value]

token_eq = (opts)->
  call =
    call: extract_fn(opts.searchType, opts.array)
    args: [':resource::json', JSON.stringify(opts.path), opts.elementType]
    cast: 'text[]'
  [':&&', call, ['^text[]', [opts.value]]]

overlap_datetime = (opts)->
  args = if opts.operator == 'lt' || opts.operator == 'le'
    ['-infinity', date.to_upper_date(opts.value)]
  else if opts.operator == 'gt' || opts.operator == 'ge'
    [date.to_lower_date(opts.value), 'infinity']
  else if opts.operator == 'eq'
    [date.to_lower_date(opts.value), date.to_upper_date(opts.value)]
  else
    throw new  Error('Unhandled')

  call =
    call: 'fhir.extract_as_daterange'
    args: [':resource::json', JSON.stringify(opts.path), opts.elementType]
    cast: 'tstzrange'

  vcall =
    call: 'tstzrange'
    args: args

  [':&&', call, vcall]

COMMON_DATE =
  eq: overlap_datetime
  ne: TODO
  gt: overlap_datetime
  ge: overlap_datetime
  lt: overlap_datetime
  le: overlap_datetime
  sa: TODO
  eb: TODO
  ap: TODO

TABLE =
  boolean:
    token:
      eq: token_eq
  code:
    token: TODO
  date:
    date: COMMON_DATE
  dateTime:
    date: COMMON_DATE
  instant:
    date: COMMON_DATE
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
      sw: (opts)-> string_ilike(opts, "%^^#{opts.value.trim()}%")
      co: (opts)-> string_ilike(opts, "%#{opts.value.trim()}%")
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
  if ['date', 'datetime', 'instant'].indexOf(resultType.toLowerCase()) > 0
    res.push('daterange')
  else
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
