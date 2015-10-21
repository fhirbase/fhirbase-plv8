OPERATORS =[
 'eq'
 'ne'
 'gt'
 'lt'
 'ge'
 'le'
 'sa'
 'eb'
 'ap'
]

MODIFIERS = [
  'missing'
  'exact'
  'contains'
  'text'
  'in'
  'below'
  'above'
  'not-in'
  'not'
  'asc'
  'desc'
]

SPECIALS = [
  '_id',
  '_lastUpdated',
  '_tag',
  '_profile',
  '_security',
  '_text',
  '_content',
  '_list',
  '_query',
  '_sort',
  '_count',
  '_include',
  '_revinclude',
  '_summary',
  '_elements',
  '_contained',
  '_containedType'
]

# param ->  (chain.)name(:modifier)=(prefix)value($other_value)
#
# related:Encounter.subject:Patient.name=ivan
#
# queryString = param ('&' param)+
# param = left '=' right // a=b
# left = chained | parameterNameWithModifier // a:Patient.b:Encounter.c
# chained = ref ('.' ref)+ '.' parameterNameWithModifier
# ref = refElement ':' resourceType # required
# parameterNameWithModifier =  parameterName (':' modifier)?
#
# parameterName = alphanum
# refElement = alphanum
# resourceType = alphanum
# modifier = MODIFIERS // enum
#
# right = opvalue (, value)+
# opvalue = op value | value
# op = OPERATORS //enum
# value = urlencoded (\|  urlencoded)+ | urlencoded ($ urlencoded)+ | urlencoded

merge = (obj, anothers...)->
  anothers.reduce(((acc, x)->
    for k,v of x when v
      acc[k] = v
    acc
  ), obj)

or_join = (arr)->
  res = ['OR']
  arr.map (x)-> res.push x
  res


# parse key
parse_left = (x)->
  if x.indexOf('.') > -1
    chain = x.split('.')
    x = chain.pop()
    chain = chain.map((x)-> x.split(':'))
  [name, modifier] = decodeURIComponent(x).split(':')
  merge({}, {name: name, modifier: modifier, chain: chain})

OPERATORS_REG =/^(eq|ne|gt|lt|ge|le|sa|eb|ap)[0-9]/
VALUE_SEP_REG= /\||\$/

parse_composite = (left, x)->
  values = x.split('$').map((y)-> parse_simple_value({},y))
  {type: 'composite', name: left.name, values: values}

parse_reference = (left, x)->
  resourceType = left.modifier
  delete left.modifier
  merge({}, {value: "#{resourceType}/#{x}"}, left)

parse_simple_value = (left, x)->
  res =  OPERATORS_REG.exec(x)
  if res && res[1]
    prefix = res[1]
    x = x.substring(2)
  if x.indexOf('|') > -1
    x = x.split('|')
  merge({}, {value: x, prefix: prefix}, left)

# parse value
parse_one_value = (left, x)->
  x = decodeURIComponent(x)
  if left.modifier && MODIFIERS.indexOf(left.modifier) == -1
    parse_reference(left, x)
  else if x.indexOf('$') > -1
    parse_composite(left, x)
  else
    parse_simple_value(left, x)

parse_right = (acc, left, x)->
  params = if x.indexOf(',') > -1
    or_join x.split(',').map((x)-> parse_one_value(left, x))
  else
    parse_one_value(left, x)
  acc.params.push(params)
  acc

include  = ()->
  if left.name == '_include' or left.name == '_revinclude'
    parse_include(left, x)

parse_count = (acc, left,right)->
  acc.count = parseInt(right)
  acc

parse_limit = (acc, left,right)->
  acc.limit = parseInt(right)
  acc

parse_sort = (acc, left, right)->
  acc.sort ||= []
  acc.sort.push([right, left.modifier])
  acc

parse_include = (acc, left,right)->
  acc.include ||= []
  acc.include.push  right.split(':')
  acc

parse_revinclude = (acc, left,right)->
  acc.revinclude ||= []
  acc.revinclude.push  right.split(':')
  acc

parse_elements = (acc, left,right)->
  acc.elements ||= []
  acc.elements = acc.elements.concat(right.split(','))
  acc

DISPATCH_TABLE =
  _sort: parse_sort
  _count: parse_count
  _limit: parse_limit
  _include: parse_include
  _revinclude: parse_revinclude
  _elements:  parse_elements

TO_PARAMS_SPECIALS = [
  '_id'
  '_lastUpdated'
  '_tag'
  '_profile'
  '_security'
  '_text'
  '_content'
  '_list'
]

dispatch = (name)->
  if TO_PARAMS_SPECIALS.indexOf(name) > -1
    return parse_right
  handler = DISPATCH_TABLE[name]
  unless handler
    throw new Error("parser for #{name} not implemented")
  handler

is_special = (left)-> left.name.indexOf('_') == 0

exports.parse = (str) ->
  return {}  if typeof str isnt "string"
  str = str.trim().replace(/^(\?|#)/, "")
  return {}  unless str
  str.trim().split("&").reduce(((acc, param)->
    parts = param.replace(/\+/g, " ").split("=")
    left = parse_left(parts[0])
    right = parts[1]
    if is_special(left)
      dispatch(left.name)(acc, left, right)
    else
      parse_right(acc, left, right)
    acc
  ), {params: ['AND']})
