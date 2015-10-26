lang = require('../lang')
lisp = require('../lispy')
sql = require('../honey')
date = require('./date')

TODO = ()->
  throw new Error("Not impl.")

extract_fn = (tbl, meta)->
  resultType = meta.searchType.toLowerCase()

  res = ["$"]

  res.push('fhir.extract_as_')

  if ['date', 'datetime', 'instant'].indexOf(resultType) > -1
    res.push('daterange')
  else
    res.push(resultType)

  res.push('_array') if meta.array

  fn = res.join('')

  [
   fn
   sql.cast(sql.q(":#{tbl}", ":resource"), sql.key('json'))
   sql.json(meta.path)
   meta.elementType
  ]


string_ilike = (tbl, meta, value)->
  ["$ilike", sql.cast(extract_fn(tbl, meta), "text"), value]

token_eq = (tbl, meta, value)->
  ["$&&", sql.cast(extract_fn(tbl, meta), ":text[]"), sql.cast(sql.array(value.value), ":text[]")]

overlap_datetime = (tbl, meta, value)->
  value = value.value
  args = if meta.operator == 'lt' || meta.operator == 'le'
    ['$tstzrange', '-infinity', date.to_upper_date(value)]
  else if meta.operator == 'gt' || meta.operator == 'ge'
    ['$tstzrange', date.to_lower_date(value), 'infinity']
  else if meta.operator == 'eq'
    ['$tstzrange', date.to_lower_date(value), date.to_upper_date(value)]
  else
    throw new  Error('Unhandled')

  ["$&&", sql.cast(extract_fn(tbl, meta), "tstzrange"), args]


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
  eq: token_eq

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
  forms ={$param: (left, right)-> condition(tbl, left, right)}
  lisp.eval_with(forms, expr)
