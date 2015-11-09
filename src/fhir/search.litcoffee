FHIRbase search implementation
====


This module is responsible for FHIR search implementation.

Search API is specified on

* [http://hl7-fhir.github.io/search.html]  
* [http://hl7-fhir.github.io/search_filter.html]  

pages.

This is a most sofistiacted part of fhirbase,
so the code split as much as possible  into small modules

`query_string` module parse query string into {query: 'ResourceType', where: [params], joins: [params]} form 
`expand_params` walk throw it and add required FHIR meta-data to each parameter 
`normalize_operators` unify operators

    parser = require('./query_string')
    helpers = require('./search_helpers')
    expand = require('./expand_params')
    namings = require('../core/namings')
    lisp = require('../lispy')
    namings = require('../core/namings')
    meta_db = require('./meta_pg')
    index = require('./meta_index')
    utils = require('../core/utils')
    pg_meta = require('../core/pg_meta')
    sql = require('../honey')
    lang = require('../lang')


For every search type we have dedicated module,
with indexing and building search expression implementation.

Every module implements and exports `handle(table_name, meta, value)` function,
which should generate honey sql predicate expression.

Such expressions usualy contains some `extract` function, because we have to extract
appropriate elements from resource by path


    SEARCH_TYPES_TABLE =
      string: require('./search_string')
      token: require('./search_token')
      reference: require('./search_reference')
      date: require('./search_date')
      number: require('./search_number')
      quantity: require('./search_quantity')
      uri: require('./search_uri')

This is main function:

@param query [Object]
 query.resourceType
 query.queryString - original query string for search

function return [SearchBundle](http://hl7-fhir.github.io/bundle.html)

Initially we need to initialize index with FHIR metainformation.
We need to look-up this index to resolve search parameter type, path and element type.

Then we are building sql query as honeysql  datastructure
(see _search_sql implementation).

If number of results is equal to our limit, we have to execute
another query for potential results count.

Then we are returning  resulting Bundle.

    exports.fhir_search = (plv8, query)->

      idx_db = ensure_index(plv8)

      honey = _search_sql(plv8, idx_db, query)
      resources = utils.exec(plv8, honey)

      if !honey.limit or (honey.limit && resources.length < honey.limit)
        count = resources.length
      else
        count = utils.exec(plv8, countize_query(honey))[0].count

      base_url = "#{query.resourceType}/#{query.queryString}"

      resourceType: 'Bundle'
      type: 'searchset'
      total: count
      link: helpers.search_links(query, count)
      entry: resources.map(to_entry)

Helper function to convert resource into entry bundle:
TODO: add links

    to_entry = (row)->
      resource: helpers.postprocess_resource(JSON.parse(row.resource))

This function should be visible from postgresql, so
we have to describe it signature:

    exports.fhir_search.plv8_signature = ['json', 'json']


Building SQL from search parameters

To build search query we need to

    normalize_operators = (expr)->
      forms =
        $param: (meta, value)->
          handler = SEARCH_TYPES_TABLE[meta.searchType]

          unless handler
            throw new Error("NORMALIZE: Not registered search type [#{meta.searchType}]")

          unless handler.normalize_operator
            throw new Error("NORMALIZE: Not implemented noramalize_operator for [#{meta.searchType}]")

          op = handler.normalize_operator(meta, value)
          meta.operator = op
          delete meta.modifier
          delete value.prefix

          ['$param', meta, value]

      lisp.eval_with(forms, expr)


    merge_where = (hsql, expr)->
      if hsql.where
        if hsql.where[0] == '$and'
          hsql.where.push(expr)
        else
          hsql.where = ['$and', hsql.where, expr]
      else if not hsql.where
        hsql.where = expr
      hsql

    _search_sql = (plv8, idx, query)->

        next_alias = mk_alias()

        alias = next_alias()

        expr = parser.parse(query.resourceType, query.queryString || "")
        expr = expand.expand(idx, expr)
        expr = normalize_operators(expr)

        expr.where = to_hsql(alias, expr.where)

        if expr.ids
          expr = merge_where(expr, ['$in', ":#{alias}.id", expr.ids])

        hsql =
          select: ':*'
          from: ['$alias', ['$q', namings.table_name(plv8, expr.query)], alias]
          where: expr.where

        if expr.joins
          hsql.join = lang.mapcat expr.joins, (x)->
            mk_join(plv8, alias, next_alias, x)

        hsql

      exports._search_sql = _search_sql


###  Building SQL from search parameters


To build search expressions, we dispatch to
implementation based on searchType

    to_hsql = (tbl, expr)->
      forms =
        $param: (left, right)->
          h = SEARCH_TYPES_TABLE[left.searchType]
          unless h
            throw new Error("Unsupported search type [#{left.searchType}] #{JSON.stringify(left)}")
          unless h.handle
            throw new Error("Search type does not exports handle fn: [#{left.searchType}] #{JSON.stringify(left)}")
          h.handle(tbl, left, right)
      lisp.eval_with(forms, expr)

    exports.to_hsql


###  Handling chained parameters

This tricky function converts chained parameters into SQL joins.


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

        [['$alias', ['$q', joined_table], join_alias], on_expr]

      last_param = lang.last(chained)
      last_cond = to_hsql(current_alias, last_param)
      last_join_cond = lang.last(res)[1]

      res[(res.length - 1)][1] = sql.and(last_join_cond, last_cond)
      res


Helper function to  generate aliases for joins:

    mk_alias = ()->
      tbl_cnt = 0 
      ()->
        tbl_cnt += 1
        "tbl#{tbl_cnt}"

To  convert search query into counting query
we just strip limit, offset, order and rewrite select clause:

    countize_query = (q)->
      delete q.limit
      delete q.offset
      delete q.order
      q.select = [':count(*) as count']
      q


We cache FHIR meta-data index per connection using plv8 object:

    ensure_index = (plv8)->
      utils.memoize plv8, 'fhirbaseIdx', -> index.new(plv8, meta_db.getter)


## Indexing

`index_parameter(query)` this function create index for parameter,
awaiting query.resourceType and query.name - name of parameter

    expand_parameter = (plv8, query)->
      idx = ensure_index(plv8)
      expr = expand.expand(idx, ['$param', query])
      if lang.isArray(expr) and expr[0] == '$or'
        expr[1..-1].map((x)-> x[1])
      else if expr[0] == '$param'
        [expr[1]]
      else
        throw new Error("Indexing: not supported #{JSON.stringify(expr)}")

    ensure_handler = (plv8, metas)->

      uniqtypes = lang.uniq(metas.map((x)-> x.searchType))
      if uniqtypes.length > 1
        throw new Error("We do not support such case #{JSON.stringify(uniqtypes)}")

      h = SEARCH_TYPES_TABLE[uniqtypes[0]]

      unless h
        throw new Error("Unsupported search type [#{meta.searchType}] #{JSON.stringify(meta)}")
      unless h.index
        throw new Error("Search type does not exports index [#{meta.searchType}] #{JSON.stringify(meta)}")

      h


    fhir_index_parameter = (plv8, query)->
      metas = expand_parameter(plv8, query)
      h = ensure_handler(plv8, metas)
      idx_infos = h.index(plv8, metas)

      for idx_info in idx_infos
        if pg_meta.index_exists(plv8, idx_info.name)
          {status: 'error', message: "Index #{idx_info.name} already exists"}
        else
          utils.exec(plv8, idx_info.ddl)
          {status: 'ok', message: "Index #{idx_info.name} was created"}

    fhir_index_parameter.plv8_signature = ['json', 'json']
    exports.fhir_index_parameter = fhir_index_parameter


    fhir_unindex_parameter = (plv8, query)->
      meta = expand_parameter(plv8, query)
      h = ensure_handler(plv8, meta)
      idx_infos = h.index(plv8, meta)
      for idx_info in idx_infos
        if pg_meta.index_exists(plv8, idx_info.name)
          utils.exec(plv8, drop: 'index', name: ":#{idx_info.name}")
          {status: 'ok', message: "Index #{idx_info.name} was dropped"}
        else
          {status: 'error', message: "Index #{idx_info.name} does not exist"}

    fhir_unindex_parameter.plv8_signature = ['json', 'json']
    exports.fhir_unindex_parameter = fhir_unindex_parameter

## Maintains

This function do analyze on resource tables to update pg statistic
args: query.resourceType

    fhir_analyze_storage = (plv8, query)->
      plv8.execute "ANALYZE #{query.resourceType.toLowerCase()}"
      message: "analyzed"

    fhir_analyze_storage.plv8_signature = ['json', 'json']
    exports.fhir_analyze_storage = fhir_analyze_storage

## Debuging fhirbase search

`fhir.search_sql(query)` is debug function, accepting same arguments as `fhir.search`
and returning SQL query string. It could be used
to analyze, what's happening under the hud.

    fhir_search_sql = (plv8, query)->
      idx_db = ensure_index(plv8)
      sql(_search_sql(plv8, idx_db, query))

    fhir_search_sql.plv8_signature = ['json', 'json']
    exports.fhir_search_sql = fhir_search_sql

    fhir_explain_search = (plv8, query)->
      idx_db = ensure_index(plv8)
      query = sql(_search_sql(plv8, idx_db, query))
      query[0] = "EXPLAIN ( ANALYZE, FORMAT JSON ) #{query[0]}"
      plv8.execute.call(plv8, query[0], query[1..-1])

    fhir_explain_search.plv8_signature = ['json', 'json']
    exports.fhir_explain_search = fhir_explain_search

## TODO

* `search_analyze`
* caching queries
