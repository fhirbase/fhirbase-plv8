sql = require('../honey')

uuid = (plv8)->
  plv8.execute('select gen_random_uuid() as uuid')[0].uuid

exports.uuid = uuid

exports.copy = (x)-> JSON.parse(JSON.stringify(x))

exports.exec = (plv8, hql)->
  q = sql(hql)
  console.log(q) if plv8.debug
  plv8.execute.call(plv8, q[0], q[1..-1])

exports.memoize = (cache, key, cb)->
  return cache[key] if cache && cache[key]
  res = cb()
  cache[key] = res if cache
  res
