xpath = require('./xpath')
lang = require('../lang')
compat = require('../compat')
utils = require('../core/utils')
namings = require('../core/namings')
search_reference = require('./search_reference')

ref_to_type_and_id = (ref)->
  return unless ref && ref.reference
  parts = ref.reference.split("/")
  tp = parts[parts.length - 2]
  id = parts[parts.length - 1]
  [tp,id]

second = (x)-> x[1]

get_includes = (includes, resources)->
  includes.map(second).reduce(((groups, inc)->
    refs = inc.reduce(((r, i)->
      r.concat(lang.mapcat(resources, (x)->
        xpath.get_in(x, [i.path])).map((r)->
          lang.merge(lang.clone(r), {target: i.target})))
      ), [])

    groups = refs.reduce(((acc, ref)->
      tp_and_id = ref_to_type_and_id(ref)
      return acc unless tp_and_id
      [tp,id] = tp_and_id
      if !ref.target || ref.target.toLowerCase() == tp.toLowerCase()
        acc[tp] = acc[tp] || {}
        acc[tp][id] = true
      acc
    ), groups)
  ), {})

load_resources = (plv8, hsql)->
  utils.exec(plv8, hsql).map((x)-> compat.parse(plv8, x.resource))

exports.load_includes = (plv8, includes, resources)->
  res = []
  groups = get_includes(includes, resources)
  for tp, ids_map of groups
    ids = lang.keys(ids_map)
    ires = load_resources plv8,
      select: [':*']
      from: ":#{namings.table_name(plv8, tp)}"
      where: ['$in', ':id', ids]
    res = res.concat(ires)
  res

exports.load_revincludes = (plv8, revincludes, resources)->
  ids = resources.map((x)-> x.id)
  lang.mapcat revincludes.map((x)-> x[1]), (inc)->
    inc.operator = 'eq'
    tbl = namings.table_name(plv8, inc[0].resourceType)
    hsql = search_reference.handle(tbl, inc, {value: ids})
    load_resources plv8,
      select: [':*']
      from: ":#{tbl}"
      where: hsql
