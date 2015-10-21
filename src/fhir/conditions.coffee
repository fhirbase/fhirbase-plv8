lang = require('../lang')
lisp = require('../lispy')
date = require('./date')

TODO = ()->
  throw new Error("Not impl.")

string_ilike = (tbl, meta, value)->
  # ['$ilike',
  #   ['$cast',  ['$call', extract_fn(meta.searchType, meta.array),
  #     ['$cast', ['$id', "resource"], "json"]
  #     ['$cast', meta.path, "json"]
  #     meta.elementType]
  #     "text"]
  #   value]
  call =
    call: extract_fn(meta.searchType, meta.array)
    args: [":#{tbl}.resource::json", JSON.stringify(meta.path), meta.elementType]
    cast: 'text'
  [':ilike', call, value]

token_eq = (tbl, meta, value)->
  # ['$&&',
  #   ['$cast', 
  #     ['$call', extract_fn(meta.searchType, meta.array),
  #     ['$cast', ['$id', "resource"], "json"]
  #     ['$cast', meta.path, "json"]
  #     meta.elementType]
  #     "text[]"]
  #   ['$array',"text[]",[value.value]]]
  call =
    call: extract_fn(meta.searchType, meta.array)
    args: [":#{tbl}.resource::json", JSON.stringify(meta.path), meta.elementType]
    cast: 'text[]'
  [':&&', call, ['^text[]', [value.value]]]

overlap_datetime = (tbl, meta, value)->

  # op = meta.operator
  # tsvalue = if op == 'lt' || op == 'le'
  #   ['$tstzrange', '-infinity', date.to_upper_date(value.value)]
  # else if op == 'gt' || op == 'ge'
  #   ['$tstzrange', date.to_lower_date(value.value), 'infinity']
  # else if op == 'eq'
  #   ['$tstzrange', date.to_lower_date(value.value), date.to_upper_date(value.value)]
  # else
  #   throw new  Error('Unhandled')

  # ['$&&',
  #   ['$cast',
  #     ['$call', "fhir.extract_as_daterange",
  #     ['$cast', ['$id', "resource"], "json"]
  #     ['$cast', meta.path, "json"]
  #     meta.elementType]
  #     "tstzrange"]
  #   tsvalue]

  value = value.value
  args = if meta.operator == 'lt' || meta.operator == 'le'
    ['-infinity', date.to_upper_date(value)]
  else if meta.operator == 'gt' || meta.operator == 'ge'
    [date.to_lower_date(value), 'infinity']
  else if meta.operator == 'eq'
    [date.to_lower_date(value), date.to_upper_date(value)]
  else
    throw new  Error('Unhandled')

  call =
    call: 'fhir.extract_as_daterange'
    args: [":#{tbl}.resource::json", JSON.stringify(meta.path), meta.elementType]
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

REFERENCE =
  eq: (tbl, meta, value)->
    call =
      call: extract_fn(meta.searchType, meta.array)
      args: [":#{tbl}.resource::json", JSON.stringify(meta.path), meta.elementType]
      cast: 'text[]'
    [':&&', call, ['^text[]', [value.value]]]

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
  Period:
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
      sw: (tbl, meta, value)-> string_ilike(tbl, meta, "%^^#{value.value.trim()}%")
      co: (tbl, meta, value)-> string_ilike(tbl, meta, "%#{value.value.trim()}%")
  Identifier:
    token: TODO
  Quantity:
    number: TODO
    quantity: TODO
  Duration: null
  Range: null
  Reference:
    reference: REFERENCE
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

condition = (tbl, meta, value)->
  handler = TABLE[meta.elementType]
  throw new Error("#{meta.elementType} is not suported") unless handler
  handler = handler[meta.searchType]
  throw new Error("#{meta.elementType} #{meta.searchType} is not suported") unless handler
  handler = handler[meta.operator]
  throw new Error("Operator #{meta.operator} in #{meta.elementType} #{meta.searchType} is not suported") unless handler
  handler(tbl, meta, value)

exports.condition = condition

exports.eval = (tbl, expr)->
  forms =
    $param: (left, right)->
      condition(tbl, left, right)

  lisp.eval_with(forms, expr)
