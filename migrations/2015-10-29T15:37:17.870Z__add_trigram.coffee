exports.up = (plv8)->
  plv8.execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

exports.down = (plv8)->
  plv8.execute "DROP EXTENSION IF EXISTS pg_trgm"
