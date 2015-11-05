sql =  require('../honey')
namings = require('./namings')
utils = require('./utils')
pg_meta = require('./pg_meta')

create_storage_sql = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, resource_type)
  constraints = [
    [":ALTER COLUMN resource SET NOT NULL"]
    [":ALTER COLUMN resource_type SET DEFAULT", sql.inlineString(resource_type)]
  ]

  [
    {
      create: "table"
      name: sql.q(nm)
      inherits: [sql.q('resource')]
    }
    {
      alter: "table"
      name: sql.q(nm)
      action:[
        [":ADD PRIMARY KEY (id)"]
        [":ALTER COLUMN created_at SET NOT NULL"]
        [":ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP"]
        [":ALTER COLUMN updated_at SET NOT NULL"]
        [":ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP"]
      ].concat(constraints)
    }
    {
      create: "table"
      name: sql.q(hx_nm)
      inherits:  [sql.q('resource_history')]
    }
    {
      alter: "table"
      name: sql.q(hx_nm)
      action:[
        [":ADD PRIMARY KEY (version_id)"]
        [":ALTER COLUMN valid_from SET NOT NULL"]
        [":ALTER COLUMN valid_to SET NOT NULL"]
      ].concat(constraints)
    }
  ].map(sql).join(";\n")


exports.create_storage_sql = create_storage_sql
exports.create_storage_sql.plv8_signature = ['json', 'json']

# TODO: rename to create_storage
exports.create_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  if pg_meta.table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} already exists"}
  else
    plv8.execute(create_storage_sql(plv8, query)) 
    {status: 'ok', message: "Table #{nm} was created"}

exports.create_storage.plv8_signature = ['json', 'json']

drop_storage_sql = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)
  [
   {drop: "table", name: sql.key(nm), safe: true}
   {drop: "table", name: sql.key(hx_nm), safe: true}
  ].map(sql).join(";\n")

exports.drop_storage_sql = drop_storage_sql
exports.drop_storage_sql.plv8_signature = ['json', 'json']

exports.drop_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  unless pg_meta.table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} not exists"}
  else
    plv8.execute(drop_storage_sql(plv8, query))
    {status: 'ok', message: "Table #{nm} was dropped"}

exports.drop_storage.plv8_signature = ['json', 'json']

exports.describe_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)
  columns = utils.exec plv8,
    select: [sql.key('column_name'), sql.key('dtd_identifier')]
    from: sql.q('information_schema','columns')
    where: {table_name: nm , table_schema: utils.current_schema(plv8)}

  name: nm
  columns: columns.reduce(((acc, x)-> acc[x.column_name] = x; delete x.column_name; acc),{})

exports.describe_storage.plv8_signature = ['json', 'json']

exports.truncate_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)
  utils.exec(plv8, truncate: sql.q(nm))
  utils.exec(plv8, truncate: sql.q(hx_nm))
  {status: 'ok', message: "Table #{nm} was truncated"}

exports.truncate_storage.plv8_signature = ['json', 'json']
