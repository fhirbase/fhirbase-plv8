xpath = require('./xpath')
index = require('./meta_index')
lang = require('../lang')

walk = (idx, resourceType, expr)->
  if lang.isArray(expr)
    expr.map((x)-> walk(idx, resourceType, x))
  else if lang.isObject(expr)
    expand_param(idx, resourceType, expr)
  else
    expr

expand_param = (idx, resourceType, x)->
  info = index.parameter(idx, [resourceType, x.name])
  res = info.map((y)-> lang.merge(y,x))
  if res.length == 1
    res[0]
  else
    ['OR'].concat(res)

exports._expand = (idx, query)->
  lang.merge query, {params: walk(idx, query.resourceType, query.params)}
