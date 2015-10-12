# This module parse xpath expressions in SearchParameter
# and provide extract functions - to get data by xpath
# parse xpath => array of paths [paths..]
# simple path just a list of elements to dig into - ['name','given']
# we also parse ```elem[attr=value]```, then item in path represented as array
# name[@use='given'] => [['name',['use','official]],'given']
# if expression in predicate is path we convert it into array
# type/system/@value => ['type','system','value']
#
# So most complicated case:
#
#  "f:Patient/f:identifier[type/coding/@code='SSN']" =>
#
#  [[['identifier', [['type','coding','code'], 'SSN']]]]
#  alternative
#  [
#    {
#     element: 'identifier',
#     cond: {
#         path: ['type','coding','code'],
#         value: 'SSN'
#       }
#    },
#    {element: 'value'}
#  ]
lang = require('../lang')

parse_pred = (x)->
  [k,v] = x.split('=').map((x)-> x.replace(/['@]/g,''))
  k = k.split('/')
  if k.length == 1 then [k[0],v] else [k,v]

parse_one = (str)->
  state = 'normal'
  res = []
  pred = []
  current = []
  push = ()->
    path_item  = current.join('').replace(/^f:/,'')
    if pred.length > 0
      res.push([path_item, parse_pred(pred.join(''))])
    else
      res.push(path_item)
    pred = []
    current = []

  for x in str
    switch state
      when 'predicat'
        if x == ']'
          state = 'normal'
        else
          pred.push(x)
      when 'normal'
        switch x
          when '/' then push()
          when '[' then state = 'predicat'
          else current.push(x)
  push()
  res

exports.parse = (xpath)->
  return unless xpath
  xpath.split(' | ').map(parse_one)

check_predicate = (node, pred)->
  return true unless pred
  [k,v] = pred
  if lang.isArray(k)
    res = get_by_path_recur([], node, k)
    res.some((x)-> x == v)
  else
    node[k] == v

get_by_path_recur = (acc, node, path)->
  next_path_item = path[0]
  predicat = null

  if lang.isArray(next_path_item)
    [next_path_item, predicat] = next_path_item

  next_node = node[next_path_item]
  next_path = path[1...]

  unless next_node
    return acc
  else if next_path.length == 0
    if lang.isArray(next_node)
      for x in next_node when check_predicate(x,predicat)
        acc.push(x)
    else
      acc.push(next_node) if check_predicate(next_node, predicat)
    return acc
  else if lang.isArray(next_node)
    next_node.reduce(((acc, x)->
      if check_predicate(x, predicat)
        get_by_path_recur(acc, x, next_path)
      else
        acc
    ), acc)
  else
    if check_predicate(next_path, predicat)
      get_by_path_recur(acc, next_node, next_path)
    else
      acc

get_by_path = (node, path)->
  get_by_path_recur([], node, path)

exports.get_in = (resource, paths)->
  res  = []
  for path in paths
    res = res.concat(get_by_path(resource, path))
  res
