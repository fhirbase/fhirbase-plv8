lang = require('../lang')
lisp = require('../lispy')


OPERATORS_REG =/^(eq|ne|gt|lt|ge|le|sa|eb|ap)[0-9]/
VALUE_SEP_REG= /\||\$/

# parse key
parse_param_left = (x)->
  [name, modifier] = decodeURIComponent(x).split(':')
  lang.merge({}, {name: name, modifier: modifier})

parse_chained_left = (x)->
  chain = x.split('.')
  x = chain.pop()
  chain = chain.map((x)-> x.split(':'))
  [name, modifier] = decodeURIComponent(x).split(':')
  lang.merge({}, {name: name, modifier: modifier, chain: chain})

parse_right =(x)->
  x.split(',').map(parse_one_value)


parse_one_value = ( x)->
  x = decodeURIComponent(x)
  match =  OPERATORS_REG.exec(x)
  res = {}
  if match && match[1]
    res.prefix = match[1]
    x = x.substring(2)
  res.value = x
  res

special_parameters = [
  '_id'
  '_lastUpdated'
  '_tag'
  '_profile'
  '_security'
  '_text'
  '_content'
  '_list'
]

is_special_param = (k)-> special_parameters.indexOf(k) > -1

specials =
  limit: (query, left, right)->
    query.limit = parseInt(right)
    query
  count: (query, left, right)->
    query.count = parseInt(right)
    query
  page: (query, left, right)->
    query.page = parseInt(right)
    query
  sort: (query, left, right)->
    key = right
    key = "#{key}:#{left}" if left
    query.sort ||= []
    query.sort.push ['$param', key, '']
    query

grouping = (acc, expr)->
  result = acc
  joins = []
  where = ['$and']
  for form in expr
    key = form[0]
    if key == '$param'
      where.push(form)
    else if key == '$chained'
      joins.push(form)
    else if is_special_param(key)
      where.push form
    else
      args = form[1...]
      parser = specials[key]
      throw new Error("No parser for special - #{key}") unless parser
      result = parser.apply(null, [result].concat(args))
  result.where = where if where.length > 1
  result.joins = joins if joins.length > 0
  result

typed = ([l,r])->
  if l.indexOf('.') > -1
    ['$chained', l, r]
  else if l.indexOf('_') == 0
    [key,mod] = l.split(':')
    key = key.replace(/^_/, '')
    [key, mod, r]
  else
    ['$param', l, r]

identity = (x)-> x

exports.parse = (resourceType, str) ->
  pairs = str.trim().split("&").filter(identity).map((x)-> x.trim().split('=')).map(typed)
  result = {query: resourceType}
  expr = grouping(result, pairs)
  forms =
    $param: (l, r)->
      left = parse_param_left(l)
      left.resourceType = resourceType
      right = parse_right(r)
      if right.length == 1
        ['$param', left, right[0]]
      else
        ['$or'].concat(right.map((x)-> ['$param', lang.clone(left), x]))
    $chained: (l, r)->
      left = parse_chained_left(l)
      right = parse_right(r)

      form = ['$chained']
      chain = left.chain
      item = null
      currentResourceType = resourceType
      for [element, rt] in chain
        item = ['$param', {resourceType: currentResourceType, name: element, join: rt}, {value: '$id'}]
        form.push(item)
        currentResourceType = rt
      meta = {resourceType: currentResourceType, name: left.name}
      meta.modifier = left.modifier if left.modifier
      if right.length == 1
        form.push ['$param', meta, right[0]]
      else
        form.push ['$or'].concat(right.map((x)-> ['$param', lang.clone(meta), x]))
      form

  lisp.eval_with(forms, expr)
