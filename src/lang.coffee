isArray = (value)->
  Array.isArray(value)

exports.isArray = isArray


assert = (x, msg)-> throw new Error(x) unless x

exports.isFn = (v)->
  typeof v == "function"

exports.isObject = (v)->
  !!v && not Array.isArray(v) && v.constructor == Object

exports.isNumber = (x)->
  not isNaN(parseFloat(x)) && isFinite(x)

isString = (x)->
  typeof x == 'string'

exports.isString = isString

isKeyword = (x)->
  isString(x) && x.indexOf && x.indexOf(':') == 0

exports.isKeyword = isKeyword

exports.keyword = (x)-> ":#{x}"

exports.name = (x)->
  if exports.isKeyword(x)
    x.replace(/^:/,'')


assert = (x, msg)->
  throw new Error(x) unless x

exports.assert = assert

exports.assertArray = (x)->
  unless isArray(x)
    throw new Error('from: [array] expected)')

interpose = (sep, col)->
  col.reduce(((acc, x)-> acc.push(x); acc.push(sep); acc),[])[0..-2]

exports.interpose = interpose

merge = (xs...)->
  xs.reduce(((acc, x)->
    for k,v of x when v
      acc[k] = v
    acc
  ), {})

exports.merge = merge

clone = (x) -> JSON.parse(JSON.stringify(x))
exports.clone = clone


exports.keys = (obj)->
  res = []
  for k,v of obj
    res.push(k)
  res

exports.mapcat = (coll, fn)->
  res = []
  for x in coll
    Array.prototype.push.apply(res, fn(x))
  res

exports.last = (arr)->
  arr[(arr.length - 1)]
