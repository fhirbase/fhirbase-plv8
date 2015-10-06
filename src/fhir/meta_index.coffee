# index of structure definitions
# for quick access to elements meta information
# handle [x] elements and complex types
FIELDS = ['path', 'min','max','type','isSummary']
upcaseFirst = (x)->
  x && x.charAt(0).toUpperCase() + x.slice(1)

clone = (x)->
  JSON.parse(JSON.stringify(x))

select_keys = (obj, keys)->
  res =  {}
  for k in keys when obj[k]
    res[k] = obj[k]
  res

assoc_in = (obj, path, res)->
  cur = obj
  for x in path[0..-2]
    cur = cur && cur[x] && cur[x].elements
  unless cur
    throw new Error("ups #{path}")
  res.elements = {}
  cur[path[(path.length - 1)]] = res
  obj

element_to_idx = (acc, el)->
  path = el.path.split('.')

  if el.path.indexOf('[x]') > -1
    val = select_keys(el, FIELDS)
    assoc_in(acc, path, val)

    last = path[(path.length - 1)]
    ppath = path.slice(0, (path.length - 1))

    for tp in el.type
      path = ppath.concat([last.replace('[x]',upcaseFirst(tp.code))])
      val = select_keys(el, FIELDS)
      val.type = [clone(tp)]
      assoc_in(acc, path, val)
  else
    val = select_keys(el, FIELDS)
    assoc_in(acc, path, val)
  acc

index_elements = (idx, sd)->
  sd.snapshot.element.reduce(element_to_idx, idx)

module.exports.add = (idx, structure_definition)->
  rt = structure_definition.name
  index_elements(idx, structure_definition)

module.exports.find = (idx, path)->
  cur = idx[path[0]]
  for p in path[1..]
    if cur && cur.elements && cur.elements[p]
      cur = cur && cur.elements && cur.elements[p]
    else
      tp = cur.type[0] && cur.type[0].code
      if tp
        sd = idx[tp]
        cur = sd && sd.elements && sd.elements[p]
      else
        cur = null
  cur

