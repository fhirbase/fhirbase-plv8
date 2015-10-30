# Search and indexing number elements

Handle numbers search queries, extract function and indexing.

This type of search is specified on http://hl7-fhir.github.io/search.html#number.

In extract_as_number is passed resource, path, element_type and returns
[numeric](http://www.postgresql.org/docs/9.3/static/datatype-numeric.html).
In case of multiple elements we return first.

TODO: handle units normalization
it should be done in an extensible maner

    xpath = require('./xpath')

    exports.plv8_schema = "fhir"

    TODO = -> throw new Error("TODO")

    exports.extract_as_number = (plv8, resource, path, element_type)->
      data = xpath.get_in(resource, [path])[0] || null
      return unless data
      if element_type == 'integer'
        data
      else if element_type == 'Quantity'
        data.value
      else
        throw new Error("extract_as_number: unsupported element type #{element_type}")

    exports.extract_as_number.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'numeric'
      immutable: true

    SUPPORTED_TYPES = ['integer', 'Quantity']
    OPERATORS = ['eq', 'lt', 'le', 'gt', 'ge']

    extract_expr = (meta, tbl)->
      from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

      ['$fhir.extract_as_number'
        ['$cast', from, ':json']
        ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
        ['$quote', meta.elementType]]

    handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Number Search: unsuported type #{JSON.stringify(meta)}")

      unless OPERATORS.indexOf(meta.operator) > -1
        throw new Error("Number Search: Unsupported operator #{meta.operator}")

      ["$#{meta.operator}", extract_expr(meta, tbl), value.value]

    exports.handle = handle

    exports.index = (plv8, meta)->
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_number"

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          on: meta.resourceType.toLowerCase()
          expression: extract_expr(meta)
      ]
