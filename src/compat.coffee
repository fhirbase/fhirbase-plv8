exports.parse = (plv8, x)->
  if typeof x == 'string'
    JSON.parse(x)
  else
    x
