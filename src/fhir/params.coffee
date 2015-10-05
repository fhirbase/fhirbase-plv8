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
]

OPS_TABLE =
  eq: 'eq'

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
# parse value
parse_right = (x)->
  res =  OPERATORS_REG.exec(x)
  if res && res[1]
    prefix = res[1]
    x = x.substring(2)
  values = x.split(',')
    .map(decodeURIComponent)
    .map((x)-> if x.match(VALUE_SEP_REG) then x.split(VALUE_SEP_REG) else x)

  merge({}, { value: values, prefix:  prefix })

exports.parse = (str) ->
  return {}  if typeof str isnt "string"
  str = str.trim().replace(/^(\?|#)/, "")
  return {}  unless str
  str.trim().split("&").map (param) ->
    parts = param.replace(/\+/g, " ").split("=")
    left = parts[0]
    right = parts[1]
    merge(parse_left(left), parse_right(right))
