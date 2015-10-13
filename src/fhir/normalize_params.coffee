lang = require('../lang')

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


normalize_param = (x)->
  x = lang.clone(x)
  handler = TABLE[x.searchType]
  unless handler
    throw new Error("NORMALIZE: Not supported #{JSON.stringify(x)}")
  if !handler.$prefix and x.prefix
    throw new Error("NORMALIZE: Prefix not suported for #{JSON.stringify(x)}")
  if !handler.$modifier and x.modifier
    throw new Error("NORMALIZE: Modifier not suported for #{JSON.stringify(x)}")

  if !x.modifier and handler.$modifier
    op = handler.$modifier
  if !x.prefix and handler.$prefix
    op = handler.$prefix

  if x.prefix and handler.$prefix
    op = handler[x.prefix]
  if x.modifier and handler.$modifier
    op = handler[x.modifier]

  unless op
    throw new Error("NORMALIZE: No operator for #{JSON.stringify(x)}")
  x.operator = op
  delete x.prefix
  delete x.modifier
  x

walk = (expr)->
  if lang.isArray(expr)
    expr.map((x)-> walk(x))
  else if lang.isObject(expr)
    normalize_param(expr)
  else
    expr

exports.normalize = (query)->
  lang.merge query, {params: walk(query.params)}
