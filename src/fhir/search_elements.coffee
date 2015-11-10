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

trim = (x)-> x && x.trim()

identity = (x)-> x

paths_to_selector = (elements)->
  result = {}
  elements.forEach (element)->
    set_in(result, element.split('.'))
  result

exports.paths_to_selector = paths_to_selector

parse_elements = (elements)->
  paths_to_selector(elements.split(',').map(trim).filter(identity))

exports.parse_elements = parse_elements 


summary_elements = (structure_definition)->
  name = structure_definition.name
  elems = structure_definition.snapshot.element
  res = ['resourceType']
  for el in elems when el.isSummary  and el.path 
    parts = el.path.split('.')[1..-1]
    last = parts[parts.length - 1]
    if last.indexOf('[x]') > -1 
      for tp in el.type
        ppath = parts[1..-1]
        typed = last.replace('[x]', lang.capitalize(tp.code))
        ppath.push(typed)
        res.push(ppath.join('.'))
    else
      res.push(parts.join('.'))
  res

exports.summary_elements = summary_elements

exports.summary_selector = (structure_definition)->
  paths_to_selector(summary_elements(structure_definition))

exports.elements = (resource, selector)->
  extract_recur = (obj, sel)->
    return obj if sel == true
    res = {}
    for k, sub_sel of sel when obj[k]
      val = obj[k]
      res[k] =
        if lang.isArray(val)
          val.map((x)-> extract_recur(x,sub_sel))
        else
          extract_recur(val, sub_sel)
    res
  extract_recur(resource, selector)
