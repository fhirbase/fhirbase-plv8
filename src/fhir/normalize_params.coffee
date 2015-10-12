lang = require('../lang')

# normalize query string to filter format
# add modifier & prefix => operator
TABLE =
  string:
    $no_prefix: true
    $no_modifier: 'co'
    exact: 'eq'
    sw: 'sw'
    ew: 'ew'


normalize_param = (x)->
  x = lang.clone(x)
  handler = TABLE[x.searchType]
  unless handler
    throw new Error("NORMALIZE: Not supported #{JSON.stringify(x)}")
  if handler.$no_prefix and x.prefix
    throw new Error("NORMALIZE: Prefix not suported for #{JSON.stringify(x)}")
  if !x.modifier and handler.$no_modifier
    op = handler.$no_modifier
  else
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
