utils = require('../core/utils')
sql = require('../honey')
namings = require('../core/namings')

exports.getter = (plv8, rt, query)->
  tbl_name = namings.table_name(plv8, rt)
  res  = if rt == 'StructureDefinition'
    utils.exec plv8,
      select: sql.raw('*')
      from: sql.q(tbl_name)
      where: {"resource->>'name'": query.name }
  else
    utils.exec plv8,
      select: sql.raw('*')
      from: sql.q(tbl_name)
      where: {"resource->>'name'": query.name, "resource->>'base'": query.base}

  if res.length > 1
    throw new Error("Unexpected behavior: more then one #{rt} #{JSON.stringify(query)}\n #{JSON.stringify(res.map((x)-> x.resource.id))}")

  if res.length < 1
    throw new Error("Not found #{rt} #{JSON.stringify(query)}")

  res[0] && JSON.parse(res[0].resource)
