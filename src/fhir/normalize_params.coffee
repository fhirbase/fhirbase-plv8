lang = require('../lang')
lisp = require('../lispy')

# normalize query string to filter format
# add modifier & prefix => operator
TABLE =
  string:
    $prefix: false
    $modifier: 'sw'
    exact: 'eq'
    contains: 'co'
    sw: 'sw'
    ew: 'ew'
  number:
    $prefix: 'eq'
    $modifier: false
    eq: 'eq'
    lt: 'lt'
    le: 'le'
    gt: 'gt'
    ge: 'ge'
    ne: 'ne'
  token:
    $prefix: false
    $modifier: 'eq'
  reference:
    $prefix: false
    $modifier: 'eq'
  date:
    $prefix: 'eq'
    $modifier: false
    eq: 'eq'
    lt: 'lt'
    le: 'le'
    gt: 'gt'
    ge: 'ge'
    ne: 'ne'


normalize_param = (meta, value)->
  meta = lang.clone(meta)
  handler = TABLE[meta.searchType]
  unless handler
    throw new Error("NORMALIZE: Not supported #{JSON.stringify(meta)}")
  if !handler.$prefix and value.prefix
    throw new Error("NORMALIZE: Prefix not suported for #{JSON.stringify(meta)}")
  if !handler.$modifier and meta.modifier
    throw new Error("NORMALIZE: Modifier not suported for #{JSON.stringify(meta)}")

  if !meta.modifier and handler.$modifier
    op = handler.$modifier
  if !value.prefix and handler.$prefix
    op = handler.$prefix

  if value.prefix and handler.$prefix
    op = handler[value.prefix]
  if meta.modifier and handler.$modifier
    op = handler[meta.modifier]

  unless op
    throw new Error("NORMALIZE: No operator for #{JSON.stringify(x)}")
  meta.operator = op
  delete value.prefix
  delete meta.modifier

  [meta, value]

exports.normalize = (expr)->
  forms =
    $param: (left, right)->
      ['$param'].concat normalize_param(left, right)
  lisp.eval_with(forms, expr)
