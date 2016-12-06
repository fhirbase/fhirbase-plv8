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
    search_common = require('./search_common')

    TODO = -> throw new Error("TODO")

    EMPTY_VALUE = "$NULL"

    extract_value = (resource, metas)->
      for meta in metas
        value = xpath.get_in(resource, [meta.path])
        if value && (value.length > 0)
          return {
            value: value
            path: meta.path
            elementType: meta.elementType
          }
      null

    exports.fhir_extract_as_reference = (plv8, resource, metas)->
      value = extract_value(resource, metas)
      res = []
      if value
        if value.elementType == 'Reference'
          for ref in value.value when ref and ref.reference
            reference = ref.reference.toLowerCase()
            parts = reference.split('/')
            len = parts.length
            res.push(parts[(len - 1)])
            res.push("#{parts[(len - 2)]}/#{parts[(len - 1)]}")
            res.push(reference) if len > 2
        else
          throw new Error("extract_as_reference: Not implemented for #{value.elementType}")
      if res.length == 0
        [EMPTY_VALUE]
      else
        res

    exports.fhir_extract_as_reference.plv8_signature =
      arguments: ['json', 'json']
      returns: 'text[]'
      immutable: true

    sf = search_common.get_search_functions({extract:'fhir_extract_as_reference'})
    extract_expr = sf.extract_expr

    OPERATORS =
      missing: (tbl, meta, value)->
        op = if value.value == 'false' then '$ne' else '$eq'
        [op
          ['$cast', extract_expr(meta, tbl), ":text[]"]
          ['$cast', ['$array', EMPTY_VALUE], ":text[]"]]


    exports.normalize_operator = (meta, value)->
      return 'missing' if meta.modifier == 'missing'
      return 'eq'

    SUPPORTED_TYPES = ['Reference']

    exports.handle = (tbl, metas, value)->
      for m in metas
        unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
          throw new Error("String Search: unsupported type #{JSON.stringify(m)}")
      operator = metas[0].operator

      if operator == "missing"
        op = if value.value == 'false' then '$ne' else '$eq'
        return [op
                 ['$cast', extract_expr(metas, tbl), ":text[]"]
                 ['$cast', ['$array', EMPTY_VALUE], ":text[]"]]

      # If `value` like /Patient/id or http://fhirbase/Patient/id
      if typeof(value.value) == 'string' &&
          (/^http/.test(value.value) || /^\//.test(value.value))

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

      val = if lang.isArray(value.value)
          ['$array'].concat(value.value)
        else
          ['$array', value.value.toLowerCase()]

      ["$&&"
        ['$cast', extract_expr(metas, tbl), ":text[]"]
        ['$cast', val, ":text[]"]]

    exports.order_expression = (tbl, metas)->
      search_token.order_expression(tbl, metas)

    exports.index = (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_reference"

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':GIN'
          on: ['$q', meta.resourceType.toLowerCase()]
          expression: [extract_expr(metas)]
      ]
