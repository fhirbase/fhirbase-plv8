xpath = require('./xpath')
index = require('./meta_index')


merge = (xs...)->
  xs.reduce(((acc, x)->
    for k,v of x when v
      acc[k] = v
    acc
  ), {})

expand_param = (idx, resourceType, x)->
  info = index.parameter(idx, [resourceType, x.name])
  res = info.map((y)-> merge(y,x))
  if res.length == 1
    res[0]
  else
    ['OR'].concat(res)

exports._expand = (idx, query)->
  merge query,
    params: query.params.map (x)->
      expand_param(idx, query.resourceType, x)
