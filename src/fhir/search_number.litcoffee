# Search and indexing number elements

Handle numbers search queries, extract function and indexing.

This type of search is specified on http://hl7-fhir.github.io/search.html#number.

In extract_as_number is passed resource, path, element_type and returns
[numeric](http://www.postgresql.org/docs/9.3/static/datatype-numeric.html).
In case of multiple elements we return first.

TODO: handle units normalization
it should be done in an extensible maner

    xpath = require('./xpath')
    search_common = require('./search_common')

    TODO = -> throw new Error("TODO")

    exports.fhir_extract_as_number = (plv8, resource, path, element_type)->
      data = xpath.get_in(resource, [path])[0] || null
      return unless data
      if element_type == 'integer' or element_type == 'positiveInt'
        data
      else if element_type = 'Duration'
        data.value
      else if element_type == 'Quantity'
        data.value
      else
        throw new Error("extract_as_number: unsupported element type #{element_type}")

    exports.fhir_extract_as_number.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'numeric'
      immutable: true

    SUPPORTED_TYPES = ['integer', 'Quantity', 'positiveInt', 'Duration']
    OPERATORS = ['eq', 'lt', 'le', 'gt', 'ge', 'ne', 'missing']

    sf = search_common.get_search_functions({
      extract:'fhir_extract_as_number',
      sort:'fhir_extract_as_number',
      SUPPORTED_TYPES:SUPPORTED_TYPES
    })
    extract_expr = sf.extract_expr

    exports.order_expression = sf.order_expression
    exports.index_order = sf.index_order

    exports.normalize_operator = (meta, value)->
      if not meta.modifier and not value.prefix
        return 'eq'
      else if meta.modifier == 'missing'
        return 'missing'
      else if OPERATORS.indexOf(value.prefix) > -1
        return value.prefix
      throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

    exports.handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Number Search: unsupported type #{JSON.stringify(meta)}")

      # unless OPERATORS.indexOf(meta.operator) > -1
      #   throw new Error("Number Search: Unsupported operator #{meta.operator}")

      op = if meta.operator == 'missing'
        if value.value == 'false' then '$notnull' else '$null'
      else
        "$#{meta.operator}"

      [op, extract_expr(meta, tbl), value.value]


    exports.index = (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_number"
      exprs = metas.map((x)-> extract_expr(x))

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          on: ['$q', meta.resourceType.toLowerCase()]
          expression: exprs
      ]
