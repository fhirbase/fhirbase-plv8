namings = require('./namings')
bundle = require('./bundle')
sql = require('../honey')
utils = require('./utils')
lang = require('../lang')

exports.plv8_schema = "core"

selector = (path)->
  path
  if path.match(/^\.\./)
    path.replace(/^\.\./,'')
  else if path.match(/^\./)
    "resource#>>'{#{path.replace(/^\./,'').replace(/\./g,',')}}'"
  else
    throw new Error('unexpected selector .elem or ..elem')

table =
  contains: (v)-> [':ilike',"%#{v}%" ]
  startWith: (v)-> [':ilike',"#{v}%" ]
  endWith: (v)-> [':ilike',"%#{v}" ]
  in: (v)-> [':in', v]
  between: (v)-> [':between', v]

isArray = lang.isArray

mk_where = (expr)->
  if isArray(expr)
    if expr[0].toLowerCase() == 'and' || expr[0].toLowerCase() == 'or'
      [":#{expr[0].toUpperCase()}"].concat(expr[1..].map(mk_where))
    else
      path = selector(expr[0])
      op = expr[1]
      v = expr[2..]
      special_handler = table[op]
      if special_handler
        [op, v] = special_handler(v)
      else
        op = ":#{op}"
        v = v[0]
      [op, "^#{path}", v]
  else
    expr

identity = (x)-> x

exports.search_sql = (plv8, query)->
  table_name = namings.table_name(plv8, query.resourceType)
  q = { select: [':*'], from: [table_name] }
  q.where = mk_where(query.query)
  q.limit = query.limit if query.limit
  q.offset = query.offset if query.offset
  q

exports.search = (plv8, query)->
  q = exports.search_sql(plv8, query)
  res = utils.exec(plv8, q)
  # console.log("RESULT", res)
  res = res.map((x)-> JSON.parse(x.resource))
  bundle.search_bundle(query, res)

exports.search.plv8_signature = ['json', 'json']
