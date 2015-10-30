sql = require('../honey')
pg_meta = require('./pg_meta')

uuid = (plv8)->
  plv8.execute('select gen_random_uuid() as uuid')[0].uuid

exports.uuid = uuid

exports.copy = (x)-> JSON.parse(JSON.stringify(x))

exports.exec = (plv8, hql)->
  q = sql(hql)
  console.log(q) if plv8.debug
  plv8.execute.call(plv8, q[0], q[1..-1])

exports.memoize = (plv8, key, cb)->
  schema = pg_meta.current_schema(plv8)
  cache = plv8.cache
  return cache[schema][key] if cache && cache[schema] && cache[schema][key]
  res = cb()
  cache[schema] ||= {}
  cache[schema][key] = res if cache
  res
