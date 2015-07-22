exports.parse = (str) ->
  return {}  if typeof str isnt "string"
  str = str.trim().replace(/^(\?|#)/, "")
  return {}  unless str
  str.trim().split("&").reduce ((ret, param) ->
    parts = param.replace(/\+/g, " ").split("=")
    key = parts[0]
    val = parts[1]
    key = decodeURIComponent(key)

    # missing `=` should be `null`:
    # http://w3.org/TR/2012/WD-url-20120524/#collect-url-parameters
    val = (if val is `undefined` then null else decodeURIComponent(val))
    unless ret.hasOwnProperty(key)
      ret[key] = val
    else if Array.isArray(ret[key])
      ret[key].push val
    else
      ret[key] = [ ret[key], val ]
    ret
  ), {}

exports.stringify = (obj) ->
  (if obj then Object.keys(obj).sort().map((key) ->
    val = obj[key]
    if Array.isArray(val)
      return val.sort().map((val2) ->
        encodeURIComponent(key) + "=" + encodeURIComponent(val2)
      ).join("&")
    encodeURIComponent(key) + "=" + encodeURIComponent(val)
  ).join("&") else "")

console.log exports.parse('a=missing:b&c=d&a=3')


###

{
  name: {$and [ ]}
}

{name: 'maud'}
//=> name=maud

{name: {$exact: 'maud'}}
//=> name:exact=maud

{name: {$or: ['maud','dave']}}
//=> name=maud,dave

{name: {$and: ['maud',{$exact: 'dave'}]}}
//=> name=maud&name:exact=Dave

{birthDate: {$gt: '1970', $lte: '1980'}}
//=> birthDate=>1970&birthDate=<=1980

{subject: {$type: 'Patient', name: 'maud', birthDate: {$gt: '1970'}}}
//=> subject:Patient.name=maud&subject:Patient.birthDate=>1970

{'subject.name': {$exact: 'maud'}}
###
