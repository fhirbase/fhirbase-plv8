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
  merge(x,info)

exports._expand = (idx, query)->
  query.params = query.params.map (x)->
    expand_param(idx, query.resourceType, x)
  query
