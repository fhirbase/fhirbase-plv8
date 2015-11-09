xpath = require('./xpath')
lang = require('../lang')
utils = require('../core/utils')
namings = require('../core/namings')

ref_to_type_and_id = (ref)->
  return unless ref && ref.reference
  parts = ref.reference.split("/")
  tp = parts[parts.length - 2]
  id = parts[parts.length - 1]
  [tp,id]

get_includes = (includes, resources)->
  groups = {}
  for inc in includes.map((x)-> x[1])
    refs = lang.mapcat resources, (x)-> xpath.get_in(x, [inc.path])
    groups = refs.reduce(((acc, ref)->
      [tp,id] = ref_to_type_and_id(ref)
      if !inc.target || inc.target.toLowerCase() == tp.toLowerCase()
        acc[tp] = acc[tp] || {}
        acc[tp][id] = true
      acc
    ), groups)

  groups

load_resources = (plv8, tp, ids)->
  utils.exec(plv8,
    select: [':*']
    from: ":#{namings.table_name(plv8, tp)}"
    where: ['$in', ':id', ids]
  ).map((x)-> JSON.parse(x.resource))

exports.load_includes = (plv8, includes, resources)->
  res = []
  groups = get_includes(includes, resources)
  for tp, ids_map of groups
    ids = lang.keys(ids_map)
    res = res.concat(load_resources(plv8, tp, ids))
  res
