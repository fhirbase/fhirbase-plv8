# FHIRbase search implementation


This module is responsible for FHIR search implementation.

Search API is specified on

* [http://hl7-fhir.github.io/search.html]  
* [http://hl7-fhir.github.io/search_filter.html]  

pages.

This is a most sofistiacted part of fhirbase,
so the code split as much as possible  into small modules

`query_string` module parse query string into {query: 'ResourceType', where: [params], joins: [params]} form 
`expand_params` walk throw it and add required FHIR meta-data to each parameter 
`noramalize_params` unify operators

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

Every module implements and exports `handle(table_name, meta, value)` function,
which should generate honey sql predicate expression.

Such expressions usualy contains some `extract` function, because we have to extract
appropriate elements from resource by path

    string_s = require('./search_string')
    token_s = require('./search_token')
    date_s = require('./search_date')
    reference_s = require('./search_reference')
    number_s = require('./search_number')
    quantity_s = require('./search_quantity')
    uri_s = require('./search_uri')

    exports.plv8_schema = "fhir"

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

Helper function to convert resource into entry bundle:
TODO: add links

    to_entry = (row)-> resource: JSON.parse(row.resource)

This function should be visible from postgresql, so
we have to describe it signature:

    exports.search.plv8_signature = ['json', 'json']


###  Building SQL from search parameters

To build search query we need to


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


###  Building SQL from search parameters

To build search expressions, we dispatch to
implementation based on searchType

    to_hsql = (tbl, expr)->
      table =
        string: string_s.handle
        token: token_s.handle
        reference: reference_s.handle
        date: date_s.handle
        number: number_s.handle
        quantity: quantity_s.handle
        uri: uri_s.handle

      forms =
        $param: (left, right)->
          h = table[left.searchType]
          unless h
            throw new Error("Unsupported search type [#{left.searchType}] #{JSON.stringify(left)}")
          h(tbl, left, right)
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
      utils.memoize plv8.cache, 'fhirbaseIdx', -> index.new(plv8, meta_db.getter)

## Debuging fhirbase search

`fhir.search_sql(query)` is debug function, accepting same arguments as `fhir.search`
and returning SQL query string. It could be used
to analyze, what's happening under the hud.

    search_sql = (plv8, query)->
      idx_db = ensure_index(plv8)
      sql(_search_sql(plv8, idx_db, query))

    search_sql.plv8_signature = ['json', 'json']
    exports.search_sql = search_sql

## TODO

* `search_analyze`
* caching queries
