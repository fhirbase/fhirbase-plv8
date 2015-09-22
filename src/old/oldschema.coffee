util = require('./util')
h = require('./honey')

init = (plv8)->

  TZ = "TIMESTAMP WITH TIME ZONE"

  for ex in ["pgcrypto", "plv8"]
    plv8.execute "create extension if not exists #{ex}"

  for tbl in ["resource", "resource_history"]
    plv8.execute h.sql(
      create: "table"
      name: tbl
      columns:
        version_id: "text"
        logical_id: ["text"]
        resource_type: ["text"]
        updated: [TZ]
        published: [TZ]
        content: ["jsonb"]
    )

exports.init  = init

drop_table = (plv8, resource_type)->
  table_name = util.table_name(resource_type)

  for tbl in [table_name, "#{table_name}_history"]
    plv8.execute("""drop table if exists #{tbl}""")

exports.drop_table  = drop_table

table_exists = (plv8, table_name)->
  result = plv8.execute """
    SELECT true FROM information_schema.tables WHERE table_name = $1;
  """, [table_name]
  result.length > 0

exports.table_exists = table_exists

generate_table = (plv8, resource_type)->
  table_name = util.table_name(resource_type)
  return if table_exists(plv8, table_name)
  plv8.execute """CREATE TABLE "#{table_name}" () INHERITS (resource)"""
  plv8.execute """
    ALTER TABLE "#{table_name}"
      ADD PRIMARY KEY (logical_id),
      ALTER COLUMN updated SET NOT NULL,
      ALTER COLUMN updated SET DEFAULT CURRENT_TIMESTAMP,
      ALTER COLUMN published SET NOT NULL,
      ALTER COLUMN published SET DEFAULT CURRENT_TIMESTAMP,
      ALTER COLUMN content SET NOT NULL,
      ALTER COLUMN resource_type SET DEFAULT '#{resource_type}'
    """
  plv8.execute """CREATE UNIQUE INDEX #{table_name}_version_id_idx ON "#{table_name}" (version_id)"""
  plv8.execute """CREATE TABLE "#{table_name}_history" () INHERITS (resource_history)"""

  plv8.execute """
    ALTER TABLE "#{table_name}_history"
      ADD PRIMARY KEY (version_id),
      ALTER COLUMN content SET NOT NULL,
      ALTER COLUMN resource_type SET DEFAULT '#{resource_type}';
    """

exports.generate_table = generate_table
