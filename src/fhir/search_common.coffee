custom_expr = (meta, tbl, opname)->
  from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

  ["$#{opname}"
   ['$cast', from, ':json']
   ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
   ['$quote', meta.elementType]]

order_expr_custom = (func_name)->
  (tbl, meta)->
    op = if meta.operator == 'desc' then '$desc' else '$asc'
    [op, custom_expr(meta, tbl, func_name)]

order_expression = (func_name, SUPPORTED_TYPES)->
  order_expr = order_expr_custom(func_name)
  (tbl, meta)->
    unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
      throw new Error("String Search: unsuported type #{JSON.stringify(meta)}")
    order_expr(tbl, meta)

extract_expr_custom = (func_name)->
  (meta, tbl)->
    custom_expr(meta, tbl, func_name)


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

      exprs = [order_expr(meta.resourceType.toLowerCase(), meta)]

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':BTREE'
          on: meta.resourceType.toLowerCase()
          expression: exprs
      ]

  }

exports.get_search_functions = get_search_functions