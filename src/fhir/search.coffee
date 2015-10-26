parser = require('./query_string')
expand = require('./expand_params')
norm = require('./normalize_params')
cond = require('./conditions')
namings = require('../core/namings')
meta_db = require('./meta_pg')
index = require('./meta_index')
utils = require('../core/utils')
sql = require('../honey')
# cases

# Patient.active
# 1 to 1; primitive
# (resource->>'active')::boolean [= <> is null]
# not selective; we do not need index for such type

# address-city

# 1 to *; complex
# a)
#   (resource#>>'{address,0,city}') ilike ~ =
#   (resource#>>'{address,1,city}') ilike ~ =
#   (resource#>>'{address,2,city}') ilike ~ =
#   (resource#>>'{address,3,city}') ilike ~ =
# we need trigram and/or fulltext index
# separate index for each index - starting from 0 and accumulating statistic
#
#  pro: more accurate result
#  contra: quite complex solution
#
# b)
#   use GIN (expr::text[]) gin_trgm_ops) or GIST
#   GIN (extract(resource, paths,opts)::text[] gin_trgm_ops)
#   one index for parameter
#
# NOTES: we need umlauts normalization for strings

mk_join = (base, next_alias, chained)->
  res = []
  current_alias = base
  for param in chained[1..-2]
    meta = param[1]
    join_alias = next_alias() 
    param[2] = {value: ":'#{meta.join}/' || #{join_alias}.id"}
    join_on = cond.eval(current_alias, param)
    res.push([sql.alias(sql.q(meta.join.toLowerCase()), join_alias), join_on])
    current_alias = join_alias
  last_param = chained[(chained.length - 1)]
  last_cond = cond.eval(current_alias, last_param)
  last_join_cond = res[(res.length - 1)][1]
  res[(res.length - 1)][1] = sql.and(last_join_cond, last_cond)
  res

_search_sql = (plv8, idx, query)->
  tbl_cnt = 0 
  next_alias = ()->
    tbl_cnt += 1
    "tbl#{tbl_cnt}"

  alias = next_alias()
  expr = parser.parse(query.resourceType, query.queryString)
  expr = expand.expand(idx, expr)
  expr = norm.normalize(expr)
  expr.where = cond.eval(alias, expr.where)

  hsql =
    select: ':*'
    from: ['$alias', ['$q', namings.table_name(plv8,expr.query)], alias]
    where: expr.where

  if expr.joins
    joins = []
    expr.joins.forEach (chained)->
      joins = joins.concat(mk_join(alias, next_alias, chained))

    hsql.join = joins
  hsql

exports._search_sql = _search_sql

search_sql = (plv8, query)->
  idx_db = index.new(plv8, meta_db.getter)
  sql(_search_sql(plv8, idx_db, query))

exports.search_sql = search_sql

countize_query = (q)->
  delete q.limit
  delete q.offset
  delete q.order
  q.select = [':count(*) as count']
  q

to_entry = (row)->
  resource: JSON.parse(row.resource)

exports.search = (plv8, query)->
  idx_db = index.new(plv8, meta_db.getter)
  honey = _search_sql(plv8, idx_db, query)
  resources = utils.exec(plv8, honey)
  if !honey.limit or (honey.limit && resources.length < honey.limit)
    count = resources.length
  else
    count = utils.exec(plv8, countize_query(honey))[0].count

  type: 'searchset'
  total: count
  entry: resources.map(to_entry)
