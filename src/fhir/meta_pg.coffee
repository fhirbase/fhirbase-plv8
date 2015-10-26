utils = require('../core/utils')
sql = require('../honey')

exports.getter = (plv8, rt, query)->
  res  = if rt == 'StructureDefinition'
    utils.exec plv8,
      select: sql.raw('*')
      from: sql.q(rt.toLowerCase())
      where: {"resource->>'name'": query.name }
  else
    utils.exec plv8,
      select: sql.raw('*')
      from: sql.q(rt.toLowerCase())
      where: {"resource->>'name'": query.name, "resource->>'base'": query.base}

  if res.length > 1
    throw new Error("Unexpected behavior: more then one #{rt} #{JSON.stringify(query)}\n #{JSON.stringify(res.map((x)-> x.resource.id))}")

  if res.length < 1
    throw new Error("Not found #{rt} #{JSON.stringify(query)}")

  res[0] && JSON.parse(res[0].resource)
