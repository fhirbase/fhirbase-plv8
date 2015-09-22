sql =  require('../honey')
namings = require('./namings')

table_exists = (plv8, table_name)->
  parts = table_name.split('.')

  if parts.length > 1
    schema_name = parts[0]
    table_name = parts[1]
  else
    schema_name = 'public'
    table_name = table_name

  q =  sql
    select: ['ok']
    from: ['information_schema.tables']
    where: [':and', [':=', ':table_name', table_name],
                    [':=', ':table_schema', schema_name]]
  result = plv8.execute(q)
  result.length > 0

exports.table_exists = table_exists

exports.create_table = (plv8, resource_type)->
  nm = namings.table_name(plv8, resource_type)
  if table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} already exists"}
  else
    plv8.execute sql(create: "table", name: nm, inherits: ['resource'])
    plv8.execute sql(create: "table", name: ['history', nm],  inherits:  ['history.resource'])
    {status: 'ok', message: "Table #{nm} was created"}

exports.drop_table = (plv8, nm)->
  nm = namings.table_name(plv8, nm)
  unless table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} not exists"}
  else
    res = plv8.execute sql(drop: "table", name: nm, safe: true)
    res = plv8.execute sql(drop: "table", name: ['history',nm], safe: true)
    {status: 'ok', message: "Table #{nm} was dropped", result: res}

exports.describe_table = (plv8, resource_type)->
  nm = namings.table_name(plv8, resource_type)
  columns = plv8.execute(sql(
    select: [':column_name', ':dtd_identifier']
    from: ['information_schema.columns']
    where: [':and',[':=',':table_name', nm]
                   [':=', ':table_schema', 'public']]))
  name: nm
  columns: columns.reduce(((acc, x)-> acc[x.column_name] = x; delete x.column_name; acc),{})

