sql = require('../honey')
utils = require('./utils')

fhirbase_disk_usage_sql = (plv8, query)->
  limit =
    if typeof(query.limit) == 'number'
      query.limit
    else
      10

  """
  SELECT nspname || '.' || relname AS "relation",
         pg_size_pretty(pg_relation_size(pg_class.oid)) AS "size"
  FROM pg_class
  LEFT JOIN pg_namespace N ON (N.oid = pg_class.relnamespace)
  WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  ORDER BY pg_relation_size(pg_class.oid) DESC
  LIMIT #{limit};
  """

exports.fhirbase_disk_usage_sql = fhirbase_disk_usage_sql

fhirbase_disk_usage = (plv8, query)->
  plv8.execute(fhirbase_disk_usage_sql(plv8, query))

exports.fhirbase_disk_usage = fhirbase_disk_usage

exports.fhirbase_disk_usage.plv8_signature = {
  arguments: ['json', 'json']
  returns: 'json'
  immutable: false
}
