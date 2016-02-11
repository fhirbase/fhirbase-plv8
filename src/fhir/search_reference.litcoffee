# Search and indexing reference elements

Handle references search queries, extract function and indexing.

This type of search is specified on http://hl7-fhir.github.io/search.html#reference.

Search by references used to build where clause and also join clauses
for chained params. `extract_as_reference` returns array of text references
and query test for array intersection.

Here is link to read more about array support in postgresql - http://www.postgresql.org/docs/9.4/static/arrays.html.

Only equality operator is implemented.


    sql = require('../honey')
    xpath = require('./xpath')
    lang = require('../lang')
    search_token = require('./search_token')

    TODO = -> throw new Error("TODO")

    EMPTY_VALUE = "$NULL"

    exports.fhir_extract_as_reference = (plv8, resource, path, element_type)->
      if element_type == 'Reference'
        res = []
        for ref in xpath.get_in(resource, [path]) when ref and ref.reference
          reference = ref.reference.toLowerCase()
          parts = reference.split('/')
          len = parts.length
          res.push(parts[(len - 1)])
          res.push("#{parts[(len - 2)]}/#{parts[(len - 1)]}")
          res.push(reference) if len > 2
        if res.length == 0
          [EMPTY_VALUE]
        else
          res
      else
        throw new Error("extract_as_reference: Not implemented for #{element_type}")

    exports.fhir_extract_as_reference.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'text[]'
      immutable: true

    extract_expr = (meta, tbl)->
      from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

      ['$fhir_extract_as_reference'
        ['$cast', from, ':json']
        ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
        ['$quote', meta.elementType]]

    OPERATORS =
      eq: (tbl, meta, value)->
        # Support for value as array
        val = if lang.isArray(value.value)
            ['$array'].concat(value.value)
          else
            ['$array', value.value.toLowerCase()]

        ["$&&"
          ['$cast', extract_expr(meta, tbl), ":text[]"]
          ['$cast', val, ":text[]"]]

      missing: (tbl, meta, value)->
        op = if value.value == 'false' then '$ne' else '$eq'
        [op
          ['$cast', extract_expr(meta, tbl), ":text[]"]
          ['$cast', ['$array', EMPTY_VALUE], ":text[]"]]


    exports.normalize_operator = (meta, value)->
      return 'eq' if not meta.modifier and not value.prefix
      return 'missing' if meta.modifier == 'missing'
      throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

    SUPPORTED_TYPES = ['Reference']

    exports.handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Reference Search: unsupported type #{JSON.stringify(meta)}")

      op = OPERATORS[meta.operator]

      unless op
        throw new Error("Reference Search: Unsupported operator #{JSON.stringify(meta)}")

      # If `value` like /Patient/id or http://fhirbase/Patient/id
      if typeof(value.value) == 'string' &&
          (value.value.startsWith('http') || value.value.startsWith('/'))

        a = value.value.split('/')

        if a[a.length - 2] == '_history'
          # If `value` like this:
          # "/Patient/id/_history/id"
          # "https://fhirbase/Patient/id/_history/id"
          value.value = [a[a.length - 4], a[a.length - 3]]
        else
          # If `value` like this:
          # "/Patient/id"
          # "http://fhirbase/Patient/id"
          value.value = [a[a.length - 2], a[a.length - 1]]

        value.value = value.value.join('/')

      op(tbl, meta, value)

    exports.order_expression = (tbl, meta)->
      search_token.order_expression(tbl, meta)

    exports.index = (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_reference"

      exprs = metas.map((x)-> extract_expr(x))
      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':GIN'
          on: meta.resourceType.toLowerCase()
          expression: exprs
      ]
