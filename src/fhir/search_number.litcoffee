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

    extract_value = (resource, metas)->
      for meta in metas
        value = xpath.get_in(resource, [meta.path])[0]
        if value
          return {
            value: value
            path: meta.path
            elementType: meta.elementType
          }
      null

    exports.fhir_extract_as_number = (plv8, resource, metas)->
      value = extract_value(resource, metas)
      if value
        if value.elementType == 'integer' or value.elementType == 'positiveInt'
          value.value
        else if value.elementType == 'Duration' or value.elementType == 'Quantity'
          value.value.value
        else
          throw new Error("extract_as_number: unsupported element type #{value.elementType}")
      else
        null

    exports.fhir_extract_as_number.plv8_signature =
      arguments: ['json', 'json']
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

    exports.handle = (tbl, metas, value)->
      for m in metas
        unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
          throw new Error("String Search: unsupported type #{JSON.stringify(m)}")
      operator = metas[0].operator

      op = if operator == 'missing'
        if value.value == 'false' then '$notnull' else '$null'
      else
        "$#{operator}"

      [op, extract_expr(metas, tbl), value.value]

    exports.index = (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_number"

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          on: ['$q', meta.resourceType.toLowerCase()]
          expression: [extract_expr(metas)]
      ]
