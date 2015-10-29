utils =  require('./utils')

table_exists = (plv8, table_name)->
  utils.memoize plv8.cache, table_name, ()->
    parts = table_name.split('.')

    if parts.length > 1
      schema_name = parts[0]
      table_name = parts[1]
    else
      schema_name = 'public'
      table_name = table_name

    result = utils.exec plv8,
      select: [':true']
      from: ['$q', 'information_schema', 'tables']
      where: {table_name: table_name, table_schema: schema_name}
    result.length > 0

exports.table_exists = table_exists

index_exists = (plv8, table_name)->
  utils.memoize plv8.cache, table_name, ()->
    parts = table_name.split('.')

    if parts.length > 1
      schema_name = parts[0]
      table_name = parts[1]
    else
      schema_name = 'public'
      table_name = table_name

    result = utils.exec plv8,
      select: [':true']
      from: [':pg_indexes']
      where: ['$eq', ':indexname::text', table_name]

    result.length > 0

exports.index_exists = index_exists
