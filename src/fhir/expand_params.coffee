xpath = require('./xpath')
index = require('./meta_index')
lang = require('../lang')
lisp = require('../lispy')

# IS FUNCTION BELOW STILL USED ANYWHERE?
expand_param = (idx, resourceType, x)->
  info = index.parameter(idx, [resourceType, x.name])
  res = info.map((y)-> lang.merge(y,x))
  if res.length == 1
    res[0]
  else
    ['$or'].concat(res)

exports.expand = (idx, expr)->
  forms =
    $param: (left, right)->
      info = index.parameter(idx, [left.resourceType, left.name])
      # console.log("!!!! INFO", JSON.stringify(info, null, 2), JSON.stringify(left, null, 2))

      if info.length > 1 && left.modifier == 'missing' && right.value == 'true' # corner case to fix issue #74
        op = '$and'
      else
        op = '$or'

      res = info.map (inf)-> ['$param', lang.merge(left, inf), right && lang.clone(right)]
      if res.length == 1
        res[0]
      else
        [op].concat(res)

  lisp.eval_with(forms, expr)
