sql = require('../src/honey')

merge = (m1, m2)->
  m2[k]=v for k,v of m1
  m2

exports.up = (plv8)->
  for ex in ["pgcrypto", "plv8"]
    plv8.execute sql({create: "extension", name: ex})

  plv8.execute sql({create: "schema", name: "history"})

  TZ = "TIMESTAMP WITH TIME ZONE"

  base_columns  = {
    id: 'TEXT'
    resource_type: 'TEXT'
    version_id: 'TEXT'
    resource: sql.JSONB
  }

  plv8.execute sql(
    create: "table"
    name: 'resource'
    columns: merge(base_columns, created_at: sql.TZ, updated_at: sql.TZ)
  )

  plv8.execute sql(
    create: "table"
    name: 'history.resource'
    columns: merge(base_columns, valid_from: sql.TZ, valid_to: sql.TZ)
  )

exports.down = (plv8)->
  for tbl in ["resource", "history.resource"]
    plv8.execute sql(drop: 'table', name: tbl)
