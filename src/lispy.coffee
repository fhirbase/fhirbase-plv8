# 'Patient', 'name=ivan' => ['$param','Patient', 'name', 'ivan']
# 'Patient', 'name=ivan,nicola' => ['$param','Patient', 'name', ['ivan', 'nicola']]
# 'Patient', 'name:exact=ivan' => ['$param','Patient', 'name', 'ivan', 'exact']
# 'Patient', 'birthdate=lt1980' => ['$param','Patient', 'name', 'ivan', 'lt']
# 'Patient', '_limit=10' => [$query 'Patient', ['$limit', 10]]
#
# ['$param','Patient', 'name', 'ivan'] => ['$eparam', {path: 'Patient.name', searchType: 'string', elementType: 'HumanName',  name: 'name'}, 'ivan']
# ['$operator', 'sw', {path: 'Patient.name', searchType: 'string', elementType: 'HumanName',  name: 'name'}, 'ivan']
lang = require('./lang')
eval_with = (table, expr)->
  if lang.isArray(expr)
    first = expr[0]
    fn = table[first]
    if fn
      args = expr[1..].map((x)-> eval_with(table, x))
      fn.apply(null, args)
    else
      expr.map((x)-> eval_with(table, x))
  else if lang.isObject(expr)
    for k,v of expr
      expr[k] = eval_with(table, v)
    expr
  else
    expr

exports.eval_with = eval_with
