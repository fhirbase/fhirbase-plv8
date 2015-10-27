# FHIRbase search implementation


This module is responsible for FHIR search implementation.

Search API is specified on

* [http://hl7-fhir.github.io/search.html]  


This is a most complicated feature of fhirbase,
so the code split as much as possible  into small modules


    parser = require('./query_string')
    expand = require('./expand_params')
    norm = require('./normalize_params')
    namings = require('../core/namings')
    lisp = require('../lispy')
    namings = require('../core/namings')
    meta_db = require('./meta_pg')
    index = require('./meta_index')
    utils = require('../core/utils')
    sql = require('../honey')
    lang = require('../lang')


For every search type we have dedicated module,
with indexing and building search expression implementation.

    string_s = require('./search_string')
    token_s = require('./search_token')
    date_s = require('./search_date')
    reference_s = require('./search_reference')

    exports.plv8_schema = "fhir"

This is main function:

@param query [Object]
 query.resourceType
 query.queryString - original query string for search

    exports.search = (plv8, query)->
      idx_db = ensure_index(plv8)
      honey = _search_sql(plv8, idx_db, query)
      resources = utils.exec(plv8, honey)
      if !honey.limit or (honey.limit && resources.length < honey.limit)
        count = resources.length
      else
        count = utils.exec(plv8, countize_query(honey))[0].count

      type: 'searchset'
      total: count
      entry: resources.map(to_entry)

    exports.search.plv8_signature = ['json', 'json']

    to_hsql = (tbl, expr)->
      table =
        string: string_s.handle
        token: token_s.handle
        reference: reference_s.handle
        date: date_s.handle

      forms =
        $param: (left, right)->
          console.log(left.searchType)
          h = table[left.searchType]
          unless h
            throw new Error("Unsupported search type [#{left.searchType}] #{JSON.stringify(left)}")
          h(tbl, left, right)
      lisp.eval_with(forms, expr)

    exports.to_hsql

This is how we handle joins
[a b c d e]
1 2 3 4 5

[b with a on ref]
[c with b on ref]
[d with c on ref]
[e with d on ref and param]

    mk_join = (plv8, base, next_alias, chained)->
      current_alias = base
      res = for param in chained[1..-2]
        meta = param[1]
        joined_resource = meta.join
        joined_table = namings.table_name(plv8, joined_resource)
        join_alias = next_alias() 
        value = {value: ":'#{joined_resource}/' || #{join_alias}.id"}

        on_expr = to_hsql(current_alias, ['$param', meta, value])
        current_alias = join_alias

        [['$alias',
            ['$q', joined_table]
            join_alias]
          on_expr]

      last_param = lang.last(chained)
      last_cond = to_hsql(current_alias, last_param)
      last_join_cond = lang.last(res)[1]

      res[(res.length - 1)][1] = sql.and(last_join_cond, last_cond)
      res


return function to alias tables 
with incapsulated counter

    mk_alias = ()->
      tbl_cnt = 0 
      ()->
        tbl_cnt += 1
        "tbl#{tbl_cnt}"

This function get plv8, index object and query
and build honey sql

    _search_sql = (plv8, idx, query)->

      next_alias = mk_alias()

      alias = next_alias()

      expr = parser.parse(query.resourceType, query.queryString)
      expr = expand.expand(idx, expr)
      expr = norm.normalize(expr)

      expr.where = to_hsql(alias, expr.where)

      hsql =
        select: ':*'
        from: ['$alias', ['$q', namings.table_name(plv8, expr.query)], alias]
        where: expr.where

      if expr.joins
        hsql.join = lang.mapcat expr.joins, (x)->
          mk_join(plv8, alias, next_alias, x)

      hsql

    exports._search_sql = _search_sql


transform honey sql to count sql
stripping limit, offset, order
and replace select

    countize_query = (q)->
      delete q.limit
      delete q.offset
      delete q.order
      q.select = [':count(*) as count']
      q

    to_entry = (row)-> resource: JSON.parse(row.resource)

    ensure_index = (plv8)->
      utils.memoize plv8.cache, 'fhirbaseIdx', -> index.new(plv8, meta_db.getter)



    search_sql = (plv8, query)->
      idx_db = ensure_index(plv8)
      sql(_search_sql(plv8, idx_db, query))

search function
accept same params as search but return generated sql
query.resourceType
query.queryString - original query string for search

    exports.search_sql = search_sql
    exports.search_sql.plv8_signature = ['json', 'json']
