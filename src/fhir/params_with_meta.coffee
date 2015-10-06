xpath = require('./xpath')

expand_param = (adapter, resourceType, x)->
  info = adapter.find_parameter(resourceType, x.name)

  unless info
    throw new Error("expand_param: No SearchParameter for #{resourceType} #{x.name}")

  x.searchType = info.type

  unless info.xpath
    throw new Error("expand_param: Could not search without xpath #{x}")

  path = xpath.parse(info.xpath)

  if path.length > 1
    throw new Error("TODO: support multi path search params")

  x.path = path[0]

  unless info.xpathUsage == 'normal'
    throw new Error("expand_param: Could not work with xpathUsage #{info.xpathUsage}")

  x.pathUsage = info.xpathUsage

  element = adapter.find_element(x.path)

  if element.type.length != 1
    throw new Error("TODO: support elements with multiple types #{resourceType} #{name}")

  x.elementType = element.type[0].code
  x.multiple = element.max == '*'
  x

exports._expand = (adapter, query)->
  query.params = query.params.map (x)->
    expand_param(adapter, query.resourceType, x)
  query

mk_adapter = (plv8)->
  cache = {}

  find_parameter: (resourceType, name)->

  find_element: (path)->
    unless cache[path]
      profile = find_structure_definition(path[0])
      epath = path.join('.')
      res = profile.snapshot.element.filter (x)-> x.path == epath
      unless res[0]
        throw new Error("#{path} not found")
      cache[path] = res[0]
      res[0]
