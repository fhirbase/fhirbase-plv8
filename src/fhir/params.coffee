PREFIXES =[
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

exports.parse = (str) ->
  return {}  if typeof str isnt "string"
  str = str.trim().replace(/^(\?|#)/, "")
  return {}  unless str
  str.trim().split("&").map (param) ->
    parts = param.replace(/\+/g, " ").split("=")
    key = parts[0]
    val = parts[1]
    key = decodeURIComponent(key)
    modifier = if val.indexOf(':') > -1
        parts = val.split(':')
        val = parts[1]
        parts[0]
      else
        null
    # missing `=` should be `null`:
    # http://w3.org/TR/2012/WD-url-20120524/#collect-url-parameters
    val = if val is `undefined` then null else val
    {operator: modifier, name: key, value: val.split(',').map(decodeURIComponent)}

console.log exports.parse('a=missing:b&c=d&a=3')
