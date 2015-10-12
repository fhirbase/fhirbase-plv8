exports.isArray = (value)->
  Array.isArray(value)

exports.isFn = (v)->
  typeof v == "function"

exports.isObject = (v)->
  !!v && not Array.isArray(v) && v.constructor == Object

exports.isNumber = (x)->
  not isNaN(parseFloat(x)) && isFinite(x)
