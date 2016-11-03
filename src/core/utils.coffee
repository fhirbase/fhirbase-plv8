sql = require('../honey')

uuid = (plv8)->
  plv8.execute('select gen_random_uuid() as uuid')[0].uuid

exports.uuid = uuid

exports.copy = (x)-> JSON.parse(JSON.stringify(x))

exports.exec = (plv8, hql)->
  q = sql(hql)
  console.log(q) if plv8.debug
  plv8.execute.call(plv8, q[0], q[1..-1])

current_schema = (plv8)->
  res = plv8.execute("SELECT current_schema")
  ( res && res[0] && res[0].current_schema ) || 'public'

exports.current_schema = current_schema

exports.memoize = (plv8, key, cb)->
  schema = current_schema(plv8)
  cache = plv8.cache
  return cache[schema][key] if cache && cache[schema] && cache[schema][key]
  res = cb()
  cache[schema] ||= {}
  cache[schema][key] = res if cache
  res
