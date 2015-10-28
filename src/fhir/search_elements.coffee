lang = require("../lang")

set_in = (obj, path) ->
  t = obj
  l = path.length
  for x,i in path
    if i == l-1
      t[x] = true
    else
      t[x] = {} unless lang.isObject(t[x])
      t = t[x]

summary_to_elements = (plv8, idx, elemnts)->

# a,a.b,c,a.b.d => [[a, [[b, [d]]], [c]]]
exports.param_to_elements = (elements)->
  result = {}
  elements.forEach (element)->
    set_in(result, element.split('.'))
  result




# {a: {c: 1, d: 3}, b: 2}, ['a.c'] => {a: {c: 1}}
mask = (resource, elements)->
