isArray = (value)->
  value and
  typeof value is 'object' and
  value instanceof Array and
  typeof value.length is 'number' and
  typeof value.splice is 'function' and
  not ( value.propertyIsEnumerable 'length' )

assertArray = (x)->
  unless isArray(x)
    throw new Error('from: [array] expected)')

assert = (x, msg)-> throw new Error(x) unless x

interpose = (sep, col)->
  col.reduce(((acc, x)-> acc.push(x); acc.push(sep); acc),[])[0..-2]

isString = (x)-> typeof x == 'string'

push = (acc, x)->
  acc.result.push(x)
  acc

concat = (acc, xs)->
  acc.result = acc.result.concat(xs)
  acc

isKeyword = (x)->
  isString(x) && x.indexOf && x.indexOf(':') == 0

isNumber = (x)->
  not isNaN(parseFloat(x)) && isFinite(x)

name = (x)->
  if isKeyword(x)
    x.replace(/^:/,'')

RAW_SQL_REGEX = /^\^/

isRawSql = (x)->
  x && isString(x) && x.match(RAW_SQL_REGEX)

rawToSql = (x)->
  x.replace(RAW_SQL_REGEX,'')

_toLiteral = (x)->
  if isKeyword(x)
    name(x)
  else if isRawSql(x)
    rawToSql(x)
  else if isNumber(x)
    x
  else
    "'#{x}'"

quote_litteral = (x)-> "'#{x}'"

quote_ident = (x)->
  x.split('.').map((x)-> "\"#{x}\"").join('.')


emit_param = (acc, v)->
  if isRawSql(v)
    push(acc,rawToSql(v))
  else if isKeyword(v)
    push(acc,name(v))
  else
    push(acc,"$#{acc.cnt}")
    acc.cnt = acc.cnt + 1
    acc.params.push(v)
  acc

surround = (acc, parens, proc)->
  push(acc,parens[0])
  acc = proc(acc)
  push(acc,parens[1])
  acc

surround_parens = (acc, proc)->
  surround acc, ['(',')'], proc

emit_delimit = (acc, delim, xs, next)->
  unless isArray(xs) # means object
    xs = ([k,v] for k,v of xs)
  for x in xs[0..-2]
    acc = next(acc, x)
    push(acc,delim)
  acc = next(acc, xs[(xs.length - 1)])
  acc

emit_columns = (acc, xs)->
  emit_delimit acc, ",", xs, (acc,x)->
    if isKeyword(x)
      push(acc,name(x))
    else if isRawSql(x)
      push(acc,rawToSql(x))
    else
      acc = emit_param(acc, x)
    acc


emit_table_name = (acc, y)->
  if isArray(y)
    push(acc, "#{quote_ident(y[0])} #{y[1]}")
  else
    push(acc, quote_ident(y))

emit_tables = (acc, x)->
  assert(x, 'from: [tables] expected')
  assertArray(x)
  push(acc,"FROM")
  emit_delimit(acc, ",", x, emit_table_name)

emit_expression = (acc, xs)->
  unless isArray(xs)
    push(acc,_toLiteral(xs))
  else
    which = xs[0]
    switch which
      when ':and'
        surround_parens acc, (acc)->
          emit_delimit(acc, "AND", xs[1..], emit_expression)
      when ':or'
        surround_parens acc, (acc)->
          emit_delimit(acc, "OR", xs[1..], emit_expression)
      else
        acc = emit_expression(acc,xs[1])
        acc = emit_expression(acc,xs[0])
        acc = emit_param(acc, xs[2])
  acc

emit_where = (acc,x)->
  return acc unless x
  push(acc,"WHERE")
  emit_expression(acc, x)

emit_join = (acc, xs)->
  return acc unless xs
  for x in xs
    push(acc,"JOIN")
    emit_table_name(acc, x[0])
    push(acc,"ON")
    emit_expression(acc, x[1])
  acc

emit_select = (acc,query)->
  push(acc,"SELECT")
  emit_columns(acc, query.select)
  emit_tables(acc, query.from)
  emit_join(acc, query.join) if query.join
  emit_where(acc, query.where)
  acc

# DDL

_to_table_name = (x)->
  if isArray(x) then x.map(quote_ident).join('.') else quote_ident(x)


_to_array = (x)->
  if isArray(x)
    x
  else if x
    [x]
  else
    []

keys = (obj)-> (k for k,_ of obj)

emit_columns_ddl = (acc, q)->
  cols = keys(q.columns).sort()
  emit_delimit acc, ",", cols, (acc, c)->
    push(acc, quote_ident(c))
    push(acc, _to_array(q.columns[c]).join(' '))

emit_create_table = (acc, q)->
  push(acc,"CREATE TABLE")
  emit_table_name(acc, q.name)
  surround_parens acc, (acc)->
    emit_columns_ddl(acc, q)

  if q.inherits
    push(acc,"INHERITS")
    surround_parens acc, (acc)->
      emit_delimit acc, ",", q.inherits, emit_table_name
  acc

emit_create_extension = (acc, q)->
  push(acc, "CREATE EXTENSION IF NOT EXISTS")
  push(acc, q.name)

emit_create_schema = (acc, q)->
  push(acc, "CREATE SCHEMA IF NOT EXISTS")
  push(acc, q.name)

emit_insert = (acc,q)->
  push(acc, "INSERT")
  push(acc, "INTO")
  push(acc, q.insert)
  names = []
  values = []
  params = []
  for k,v of q.values
    names.push(k)
    if isRawSql(v)
      values.push(rawToSql(v))
    else
      values.push("$#{acc.cnt}")
      acc.params.push(v)
      acc.cnt = acc.cnt + 1

  surround_parens acc, (acc)->
    emit_delimit acc, ',', names, (acc, nm)->
      push(acc, nm)

  push(acc, "VALUES")

  surround_parens acc, (acc)->
    emit_delimit acc, ',', values, (acc, v)->
      push(acc, v)
  acc

emit_update = (acc, q)->
  push(acc, "UPDATE")
  push(acc, q.update)
  acc = emit_delimit acc, ",", q.values, (acc, [k,v])->
    push(acc, "#{k} = ")
    emit_param(acc, v)
  acc = emit_where(acc, q.where)

emit_create = (acc, q)->
  switch q.create
    when 'table' then emit_create_table(acc, q)
    when 'extension' then emit_create_extension(acc, q)
    when 'schema' then emit_create_schema(acc, q)

emit_drop = (acc, q)->
 push(acc, "DROP")
 push(acc, q.drop)
 push(acc, "IF EXISTS") if q.safe
 push(acc, _to_table_name(q.name))


sql = (q)->
  #console.log("HQL:", q)
  acc = { cnt: 1, result: [], params: [] }
  acc = if q.create
    emit_create(acc, q)
  else if q.insert
    emit_insert(acc, q)
  else if q.update
    emit_update(acc, q)
  else if q.drop
    emit_drop(acc,q)
  else if q.select
    emit_select(acc, q)

  [acc.result.join(" ")].concat(acc.params)

module.exports = sql

sql.TZ = "TIMESTAMP WITH TIME ZONE"
sql.JSONB = "jsonb"

comment = ->
  console.log sql(
     select: [":a","^b",'c'],
     from: ['users','roles'],
     joins: [['roles', [':=', '^r.user_id', '^users.id']]]
     where: [':and', [':=', ':id', 5],[':=', ':name', 'x']]
  )

  console.log sql(
    update: "users",
    values: {a: 1, b: '^current_timestamp'},
    where: [':=', ':id', 5]
  )
