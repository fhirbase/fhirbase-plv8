sql =  require('../honey')
namings = require('./namings')
utils = require('./utils')
pg_meta = require('./pg_meta')

# TODO: rename to create_storage
exports.create_storage = (plv8, resource_type)->
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, resource_type)
  if pg_meta.table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} already exists"}
  else
    utils.exec plv8,
      create: "table"
      name: sql.q(nm)
      inherits: [sql.q('resource')]

    constraints = [
      [":ALTER COLUMN resource SET NOT NULL"]
      [":ALTER COLUMN resource_type SET DEFAULT", sql.inlineString(resource_type)]
    ]

    utils.exec plv8,
      alter: "table"
      name: sql.q(nm)
      action:[
        [":ADD PRIMARY KEY (id)"]
        [":ALTER COLUMN created_at SET NOT NULL"]
        [":ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP"]
        [":ALTER COLUMN updated_at SET NOT NULL"]
        [":ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP"]
      ].concat(constraints)

    utils.exec plv8,
      create: "table"
      name: sql.q(hx_nm)
      inherits:  [sql.q('resource_history')]

    utils.exec plv8,
      alter: "table"
      name: sql.q(hx_nm)
      action:[
        [":ADD PRIMARY KEY (version_id)"]
        [":ALTER COLUMN valid_from SET NOT NULL"]
        [":ALTER COLUMN valid_to SET NOT NULL"]
      ].concat(constraints)

    {status: 'ok', message: "Table #{nm} was created"}

exports.drop_storage = (plv8, nm)->
  nm = namings.table_name(plv8, nm)
  hx_nm = namings.history_table_name(plv8, nm)
  unless pg_meta.table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} not exists"}
  else
    utils.exec(plv8, drop: "table", name: sql.key(nm), safe: true)
    utils.exec(plv8, drop: "table", name: sql.key(hx_nm), safe: true)
    if plv8.cache
      delete plv8.cache[nm]
      delete plv8.cache["#{hx_nm}"]
    {status: 'ok', message: "Table #{nm} was dropped"}

exports.describe_table = (plv8, resource_type)->
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)
  columns = utils.exec plv8,
    select: [sql.key('column_name'), sql.key('dtd_identifier')]
    from: sql.q('information_schema','columns')
    where: {table_name: nm , table_schema: utils.current_schema(plv8)}

  name: nm
  columns: columns.reduce(((acc, x)-> acc[x.column_name] = x; delete x.column_name; acc),{})

exports.truncate_storage = (plv8, resource_type)->
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)
  utils.exec(plv8, truncate: sql.q(nm))
  utils.exec(plv8, truncate: sql.q(hx_nm))
  {status: 'ok', message: "Table #{nm} was truncated"}
