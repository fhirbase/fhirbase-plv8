custom_expr = (metas, tbl, opname)->
  from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'
  m = metas.map((x)-> {path: x.path, elementType: x.elementType})
  ["$#{opname}"
   ['$cast', from, ':json']
   ['$cast', ['$quote', JSON.stringify(m)], ':json']]

order_expr_custom = (func_name)->
  (tbl, metas)->
    op = if metas[0].operator == 'desc' then '$desc' else '$asc'
    [op, custom_expr(metas, tbl, func_name)]

order_expression = (func_name, SUPPORTED_TYPES)->
  order_expr = order_expr_custom(func_name)
  (tbl, metas)->
    for m in metas
      unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
        throw new Error("String Search: unsuported type #{JSON.stringify(m)}")
    order_expr(tbl, metas)

extract_expr_custom = (func_name)->
  (metas, tbl)->
    custom_expr(metas, tbl, func_name)

get_search_functions = (obj) ->
  extract = obj.extract
  sort = obj.sort
  SUPPORTED_TYPES = obj.SUPPORTED_TYPES
  order_expr = order_expr_custom(sort)
  {
    order_expression: order_expression(sort, SUPPORTED_TYPES)
    extract_expr: extract_expr_custom(extract)
    index_order : (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_order"

      exprs = [order_expr(meta.resourceType.toLowerCase(), metas)]

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':BTREE'
          on: ['$q', meta.resourceType.toLowerCase()]
          expression: exprs
      ]
  }

exports.get_search_functions = get_search_functions
