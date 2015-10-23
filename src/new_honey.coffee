lang = require('./lang')

mk_result = ->
  cnt = 0
  res =
    result: []
    params: []
    push: (str)->
      res.result.push(str)
    add_param: (x)->
      res.result.push("$#{cnt+1}")
      res.params.push(x)
      cnt = cnt + 1
    to_sql: ()->
      [res.result.join(" ")].concat(res.params)
  res

from = (res, expr)->
  if lang.isArray(expr)
    if isSymbol(expr[0])
      heval(res, expr)
    else
      comma_delimited res, expr, (x)-> heval(res, x)
  else
    heval(res, expr)

comma_delimited = (res, xs, cb)->
  cb(xs[0])
  for x in xs[1..]
    res.push(",")
    cb(x)

delimited = (res, delim, xs, cb)->
  cb(xs[0])
  for x in xs[1..]
    res.push(delim)
    cb(x)

select_clause = (res, expr)->
  if lang.isArray(expr)
    if isSymbol(expr[0])
      heval(res, expr)
    else
      comma_delimited res, expr, (x)-> heval(res, x)
  else
    heval(res, expr)

where_clause = (res, expr)->
  res.push("WHERE")
  if lang.isObject(expr)
    fexpr = ['$and']
    for k,v of expr
      fexpr.push(['$eq', ":#{k}", v])
    heval(res, fexpr)
  else
    heval(res, expr)

join_clause = (res, expr)->
  for [tbl, on_exp] in expr
    res.push("JOIN")
    heval(res, tbl)
    res.push("ON")
    heval(res, on_exp)

select = (res, expr)->
  res.push("SELECT")
  select_clause(res, expr.select)
  res.push("FROM")
  from(res, expr.from)
  where_clause(res, expr.where) if expr.where
  join_clause(res, expr.join) if expr.join

_delete = (res, expr)->
  res.push("DELETE FROM")
  heval(res, expr.delete)
  if expr.where
    where_clause(res, expr.where)

update = (res, expr)->
  res.push("UPDATE")
  heval(res, expr.update)
  res.push("SET")
  kvs = ([k,v] for k,v of expr.values)
  comma_delimited res, kvs, ([k,v])->
    res.push(k)
    res.push("=")
    heval(res, v)
  if expr.where
    where_clause(res, expr.where)

insert = (res, expr)-> 
  res.push("INSERT INTO")
  heval(res, expr.insert)
  names = []
  values = []

  for k,v of expr.values
    names.push(k)
    values.push(v)

  console.log(names, values)

  res.push("(")
  comma_delimited res, names, res.push
  res.push(")")

  res.push("VALUES")

  res.push("(")
  comma_delimited res, values, (x)-> heval(res, x)
  res.push(")")

  ret = expr.returning
  if ret
    res.push("RETURNING")
    ret = [ret] unless lang.isArray(ret)
    comma_delimited res, ret, (x)-> heval(res, x)

array = (res, expr)-> 
  'array'

function_call = (res, [fn, args...])->
  res.push("#{name(fn)}(")
  comma_delimited res, args, (x)-> heval(res, x)
  res.push(")")

raw = (res, expr)->
  res.push(expr.replace(/^:/, ''))

ignore = (res, expr)->  
 console.log('ignore', expr)

isSymbol = (x)-> x && x.indexOf && x.indexOf('$') == 0

isKeyword = (x)-> x && x.indexOf && x.indexOf(':') == 0

name = (x)-> x.replace(/^(:|\$)/,'')

parameter = (res, expr)->
  if lang.isArray(expr)
    throw new Error("TODO")
  else if lang.isObject(expr)
    throw new Error("TODO")
  else
    res.add_param(expr)

infix_operator = (op_symbol)->
  (res, [op, left, right])->
    heval(res, left)
    res.push(op_symbol)
    heval(res, right)

multi_infix_operator = (op_symbol)->
  (res, [op, args...])->
    res.push("(")
    delimited res, op_symbol, args, (x)-> heval(res, x)
    res.push(")")

BUILTINS =
  $lt: infix_operator('<')
  $le: infix_operator('<=')
  $gt: infix_operator('>')
  $ge: infix_operator('>=')
  $eq: infix_operator('=')
  "$&&": infix_operator('&&')
  $and: multi_infix_operator('AND')
  $or: multi_infix_operator('OR')
  $raw: (res, [op, str])->
    res.push(str)
  $alias: (res, [op, expr, alias])->
    console.log('alias', op, expr, alias)
    heval(res, expr)
    res.push(name(alias))
  $q: (res, [op, sch, id])->
    res.push "#{name(sch)}.#{name(id)}"
  $as: (res, [op, expr, as])->
    heval(res, expr)
    res.push("AS")
    res.push(name(as))
  $cast: (res, [op, expr, tp])->
    res.push("(")
    heval(res, expr)
    res.push(")::#{name(tp)}")
  $json: (res, [op, json])->
    res.push("to_json(")
    res.add_param(JSON.stringify(json))
    res.push(")")


CREATE_CLAUSES =
  extension: (res, expr)->
    res.push("CREATE EXTENSION")
    res.push("IF NOT EXISTS") if expr.safe
    res.push(name(expr.name))
  table: (res, expr)->
    res.push("CREATE TABLE")
    res.push("IF NOT EXISTS") if expr.safe
    res.push(name(expr.name))
    res.push("(")
    if expr.columns
      comma_delimited res, expr.columns, (column)->
        heval(res, x) for x in column
    res.push(")")
    inherits = expr.inherits
    if inherits
      res.push("INHERITS")
      inherits = [inherits] unless lang.isArray(inherits)
      res.push("(")
      comma_delimited res, inherits, (x)->
        heval(res, x)
      res.push(")")

drop = (res, expr)->
  res.push("DROP")
  res.push(name(expr.drop).toUpperCase())
  if expr.safe
    res.push("IF EXISTS")
  heval(res, expr.name)
  if expr.cascade
    res.push("CASCADE")

truncate = (res, expr)->  
  res.push("TRUNCATE")
  heval(res, expr.truncate)
  if expr.restart
    res.push("RESTART IDENTITY")
  if expr.cascade
    res.push("CASCADE")

alter = (res, expr)->
  res.push("TODO") 

_type = (expr)->
  if lang.isArray(expr)
    op = expr[0]
    if isSymbol(op)
      BUILTINS[op] or function_call
    else
      array
  else if isKeyword(expr)
    raw
  else if lang.isObject(expr)
    if expr.insert
      insert
    else if expr.update
      update
    else if expr.delete
      _delete
    else if expr.drop
      drop
    else if expr.truncate
      truncate
    else if expr.alter
      alter
    else if expr.select
      select
    else if expr.create
      handler = CREATE_CLAUSES[name(expr.create)]
      throw new Error("No handler for create #{expr.create}") unless handler
      handler
    else
      parameter
  else
    parameter

heval = (res, expr)->
  tp = _type(expr)
  tp(res, expr)
  res.to_sql()

sql = (expr)->
  res = mk_result()
  heval(res, expr)

module.exports = sql
