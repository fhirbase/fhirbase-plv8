xpath = require('./xpath')
index = require('./meta_index')
lang = require('../lang')
lisp = require('../lispy')

exports.expand = (idx, expr)->
  forms =
    $param: (left, right)->
      info = index.parameter(idx, [left.resourceType, left.name])
      metas = info.map (inf)-> lang.merge(left, inf)
      ['$param', metas, right && lang.clone(right)]

  lisp.eval_with(forms, expr)
