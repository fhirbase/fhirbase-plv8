sql = require('../honey')

isArray = (value)->
  value and
  typeof value is 'object' and
  value instanceof Array and
  typeof value.length is 'number' and
  typeof value.splice is 'function' and
  not ( value.propertyIsEnumerable 'length' )

addParam = (env, x)->
  res = "$#{env.cnt}"
  env.cnt = env.cnt + 1
  env.params.push(x)
  res

merge = (into, args)->
  args.reduce(((acc, x)->
    for k,v of x
      if acc[k]
        acc[k].push(v)
      else
        acc[k] = v
    acc
  ), into)

key_merge = (key, init, args)->
  for a in args when a[key]
    init.push(a[key])
  res = merge({}, args)
  res[key] = init
  res

TABLE =
  search: (env,[resourceType, args...])->
    merge({select: [':*'], from: [resourceType]}, args)
  '=': (env, [left, right]) ->
    {where: [':=', left, right]}
  contains: (env, [left, right])->
    {where: [':&&', left, right]}
  param: (env, path)->
    {call: 'extract', args: [':resource', path], array: true}
  and: (env, args)->
    key_merge('where', [':and'], args)
  or: (env, args)->
    key_merge('where', [':or'], args)
  ref: (env, [field,res])->
    {join: [[[res,res], [':=', "^ref(#{field})",':id']]]}
  join: (env, args)-> merge({}, args)
  limit: (env, [num])-> {limit: num}
  asc: (env, [col])->
    {order: [col, 'asc']}
  desc: (env, [col])->
    {order: [col, 'desc']}
  order: (env, args)->
    key_merge('order',[],args)
  offset: (env, [num])-> {offset: num}

_eval = (env,expr)->
  if expr.length == 1 and not isArray(expr[0])
    return expr[0]
  op = expr[0]
  fn = TABLE[op]
  throw new Error("Unbound symbol #{op}") unless fn
  args = expr[1...].map((x)-> _eval(env,(if isArray(x) then x else [x])))
  fn(env, args)


env = {
  params: []
  cnt: 1
}

program = ['search',
  'Patient'
  ['order', ['asc', 'name']]
  ['limit', 10]
  ['join', ['ref', 'organization', 'Organization']]
  ['and',
    ['=', ['param', 'type'], 'animal']
    ['or',
      ['contains', ['param', 'name', 'given'], 'ivan']
      ['=', ['param', 'active'], 'true']]]
  ['offset', 10]]

res = _eval(env,program)
console.log sql(res)

delete res.order
delete res.limit
delete res.offset
res.select = ['^count(*)']

console.log sql(res)

