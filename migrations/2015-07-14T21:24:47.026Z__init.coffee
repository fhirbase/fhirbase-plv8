sql = require('../src/honey')

exports.up = (plv8)->
  for ex in ["pgcrypto", "plv8"]
    plv8.execute "create extension if not exists #{ex}"

  plv8.execute "create schema history"

  TZ = "TIMESTAMP WITH TIME ZONE"

  for tbl in ["resource", "history.resource"]
    plv8.execute sql(
      create: "table"
      name: tbl
      columns:
        resource_type: 'TEXT'
        id: 'TEXT'
        vid: 'TEXT'
        valid_from: TZ
        valid_to: TZ
        resource: 'JSONB'
    )

exports.down = (plv8)->
  # plv8.execute ""
  throw new Error('Not implemented')
