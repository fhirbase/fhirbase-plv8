# index of structure definitions
# for quick access to elements meta information
# handle [x] elements and complex types
xpath = require('./xpath')

search_elements = require('./search_elements')

lang = require('../lang')

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

index_elements = (idx, structure_definition)->
  structure_definition.snapshot.element.reduce(element_to_idx, idx)

# counstruct idx object from getter
# getter is function which should return structure definition by name
# getter(name)-> StructureDefinition
module.exports.new = (plv8, getter)->
  elements = {}
  summaries = {}
  params = {}

  elements: elements
  params: params
  summaries: summaries
  summary_selector: (rt)->
    unless summaries[rt]
      sd = getter(plv8, 'StructureDefinition', {name: rt})
      summaries[rt] = search_elements.summary_selector(sd)
    summaries[rt]
  get: (rt, query)->
    if rt == 'StructureDefinition'
      unless elements[query.name]
        sd = getter(plv8, rt, query)
        sd && index_elements(elements, sd)
      elements[query.name]
    else if rt == 'SearchParameter'
      key = "#{query.base}-#{query.name}"
      if params[key] == undefined
        sp = getter(plv8, rt, query)
        params[key] = (sp && select_keys(sp, ['xpath', 'type', 'xpathUsage'])) || null
      params[key]
    else
      throw new Error("unexpected call")

element = (idx, path)->
  cur = idx.get('StructureDefinition', name: path[0])
  for p in path[1..] when cur
    if cur.elements && cur.elements[p]
      cur = cur && cur.elements && cur.elements[p]
    else
      tp = cur.type && cur.type[0] && cur.type[0].code
      if tp
        sd = idx.get('StructureDefinition', name: tp)
        cur = sd && sd.elements && sd.elements[p]
      else
        cur = null
  cur

module.exports.element = element

module.exports.parameter = (idx, path)->
  resourceType = path[0]
  name = path[1]
  sp = idx.get('SearchParameter', base: resourceType, name: name)

  unless sp
    throw new Error("MetaIndex: Param not found #{path.join('-')}")

  unless sp.xpath
    throw new Error("MetaIndex: Param does not have xpath #{path.join('-')}")

  epathes = xpath.parse(sp.xpath)

  if epathes.length < 1
    throw new Error("MetaIndex: Path not expandable #{path.join('-')}")

  epathes.map (epath)->
    epath = epath.map((x)-> if lang.isArray(x) then x[0] else x)
    el = element(idx, epath)
    throw new Error("MetaIndex: Element [#{JSON.stringify(path)}] -> #{epath.join('.')} not found") unless el

    name: name
    path: epath
    multiple: el.max == '*'
    searchType: sp.type
    elementType: el.type[0].code
    pathUsage: sp.xpathUsage
