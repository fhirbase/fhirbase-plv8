sql = require('../src/honey')

merge = (m1, m2)->
  m2[k]=v for k,v of m1
  m2

exports.up = (plv8)->
  for ex in [":pgcrypto", ":plv8"]
    plv8.execute sql({create: "extension", name: ex, safe: true})

  plv8.execute sql({create: "schema", name: ":history", safe: true})

  TZ = "TIMESTAMP WITH TIME ZONE"

  base_columns  =[
    [':id',':text']
    [':version_id',':text']
    [':resource_type',':text']
    [':resource',':jsonb']
  ]

  plv8.execute sql(
    create: ":table"
    name: ':resource'
    columns: base_columns.concat([
      [':created_at', ':timestamp with time zone']
      [':updated_at', ':timestamp with time zone']
    ])
  )

  plv8.execute sql(
    create: ":table"
    name: ['$q', ':history', ':resource']
    columns: base_columns.concat([
      [':valid_from', ':timestamp with time zone']
      [':valid_to', ':timestamp with time zone']
    ])
  )

exports.down = (plv8)->
  for tbl in [":resource", ":history.resource"]
    plv8.execute sql(drop: ':table', name: tbl)
