namings = require('./namings')
bundle = require('./bundle')

parentize = (x)-> "( #{x} )"

selector = (path)->
  if path.match(/^\./)
    " #{path.replace(/^\./,'')} "
  else
    " resource#>>'{#{path}}' "


table =
  and: (clouses...)->
    parentize(clouses.map(emit).join(' AND '))

  or: (clouses...)->
    parentize(clouses.map(emit).join(' OR '))

  contains: (path, value)->
    " #{selector(path)} ilike '%#{value}%' "

  startWith: (path, value)->
    " #{selector(path)} ilike '#{value}%' "

  endWith: (path, value)->
    " #{selector(path)} ilike '%#{value}' "

  in: (path, values...)->
    sql_str = values.map((x)-> "'#{x}'").join(',')
    " #{selector(path)} in (#{sql_str}) "
  between: (path, upper, lower)->
    " #{selector(path)} between '#{upper}' and '#{lower}' "

  '=': (path, value)->
    " #{selector(path)} = '#{value}' "

  '!=': (path, value)->
    " #{selector(path)} <> '#{value}' "

  '>': (path, value)->
    " #{selector(path)} > '#{value}' "

  '>=': (path, value)->
    " #{selector(path)} >= '#{value}' "

  '<': (path, value)->
    " #{selector(path)} < '#{value}' "

  '<=': (path, value)->
    " #{selector(path)} <= '#{value}' "


emit = (expr)->
  return null unless expr
  op = expr[0]
  handler = table[op]
  unless handler
    throw new Error("Operator #{op} not recognised")
  handler.apply(null, expr[1..-1])

identity = (x)-> x

exports.search_sql = (plv8, query)->
  table_name = namings.table_name(plv8, query.resourceType)
  expr = ["SELECT * FROM #{table_name}"]
  where = emit(query.query)
  where = "WHERE #{where}" if where
  expr.push(where)
  if query.limit
    expr.push("LIMIT #{query.limit}")
  if query.offset
    expr.push("OFFSET #{query.offset}")
  expr.filter(identity).join("\n")

exports.search = (plv8, query)->
  sql = exports.search_sql(plv8, query)
  console.log("SQL: ", sql)
  res = plv8.execute(sql)
  bundle.search_bundle(query, res.map((x)-> JSON.parse(x.resource)))

comment = ->
  q =
    resourceType: 'Something'
    query: ['contains', 'name', 'som']

  q =
    resourceType: 'Something'
    limit: 100
    offset: 5
    query: ['and', ['contains', 'name', 'som'],
                   ['=', 'name', 'something']]

  console.log exports.search_sql(null, q)
