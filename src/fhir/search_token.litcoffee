# Search and indexing token elements

Handle tokens search queries, extract function and indexing.

This type of search is specified on http://hl7-fhir.github.io/search.html#token.

In extract_as_token is passed resource, path, element_type and returns
array of texts. Different coded types behaviour just hardcoded.

PostgreSQL implementation is based on arrays support - http://www.postgresql.org/docs/9.4/static/arrays.html.


    sql = require('../honey')
    lang = require('../lang')
    xpath = require('./xpath')
    search_common = require('./search_common')

    SUPPORTED_TYPES = [
      'uri'
      'boolean'
      'code'
      'string'
      'CodeableConcept'
      'Coding'
      'ContactPoint'
      'Identifier'
      'Reference'
      'Quantity'
      'dateTime'
      'date'
    ]

    sf = search_common.get_search_functions({extract:'fhir_extract_as_token', sort:'fhir_sort_as_token',SUPPORTED_TYPES:SUPPORTED_TYPES})
    extract_expr = sf.extract_expr

    exports.order_expression = sf.order_expression
    exports.index_order = sf.index_order

    TODO = -> throw new Error("TODO")

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

    exports.fhir_extract_as_token = (plv8, resource, metas)->
      res = []
      data = extract_value(resource, metas)
      if data
        if data.elementType == 'boolean'
          res = for str in data.value
            if str.toString() == 'false'
              'false'
            else
              'true'
        else if data.elementType == 'dateTime' or data.elementType == 'date'
          res = if data.value.length > 0 then ['true', 'false'] else []
        else if data.elementType == 'code' || data.elementType == 'string' || data.elementType == 'uri'
          res = (str.toString().toLowerCase() for str in data.value)
        else if data.elementType == 'Identifier' or data.elementType == 'ContactPoint'
          for coding in data.value
              res.push(coding.value.toString().toLowerCase()) if coding.value
              res.push("#{coding.system}|#{coding.value}".toLowerCase())
        else if data.elementType == 'Coding'
          for coding in data.value
              res.push(coding.code.toString().toLowerCase()) if coding.code
              res.push("#{coding.system}|#{coding.code}".toLowerCase())
        else if data.elementType == 'Quantity'
          for quant in data.value
              res.push(quant.code.toString().toLowerCase()) if quant.code
              res.push(quant.unit.toString().toLowerCase()) if quant.unit
              res.push("#{quant.system}|#{quant.code}".toLowerCase())
              res.push("#{quant.system}|#{quant.unit}".toLowerCase())
        else if data.elementType == 'CodeableConcept'
          for concept in data.value
            for coding in (concept.coding || [])
              res.push(coding.code.toString().toLowerCase()) if coding.code
              res.push("#{coding.system}|#{coding.code}".toLowerCase())
        else if data.elementType == 'Reference'
          for ref in data.value
            res.push(ref.reference)
        else
          throw new Error("fhir_extract_as_token: Not implemented for #{data.elementType}")

      if res.length == 0
        ['$NULL']
      else
        res

    exports.fhir_extract_as_token.plv8_signature =
      arguments: ['json', 'json']
      returns: 'text[]'
      immutable: true

    exports.fhir_sort_as_token = (plv8, resource, metas)->
      value = extract_value(resource, metas)
      return null unless value
      data = value.value[0]

      if value.elementType == 'boolean'
        if data.toString() == 'false' then 'false' else 'true'
      else if value.elementType == 'code' || value.elementType == 'string' || value.elementType == 'uri'
        data.toString()
      else if value.elementType == 'Identifier' or value.elementType == 'ContactPoint'
        [data.system, data.value].join('0').toLowerCase()
      else if value.elementType == 'Coding'
        [data.system, data.code, data.display].join('0').toLowerCase()
      else if value.elementType == 'Quantity'
        [data.system, data.unit, data.code].join('0').toLowerCase()
      else if value.elementType == 'CodeableConcept'
        coding = data.coding && data.coding[0]
        if coding
          [coding.system, coding.code, coding.display].join('0').toLowerCase()
        else
          data.text || JSON.stringify(data)
      else if value.elementType == 'Reference'
        data.reference
      else
        throw new Error("fhir_extract_as_token: Not implemented for #{value.elementType}")

    exports.fhir_sort_as_token.plv8_signature =
      arguments: ['json', 'json']
      returns: 'text'
      immutable: true

    OPERATORS =
      missing: (tbl, metas, value)->
        op = if value.value == 'false' then '$ne' else '$eq'
        [op
          ['$cast', extract_expr(metas, tbl), ":text[]"]
          ['$cast', ['$array', "$NULL"], ":text[]"]]

      eq: (tbl, metas, value)->
        ["$&&"
          ['$cast', extract_expr(metas, tbl), ":text[]"]
          ['$cast', ['$array', value.value.toString().toLowerCase()], ":text[]"]]


    exports.normalize_operator = (meta, value)->
      return 'eq' if not meta.modifier and not value.prefix
      return 'missing' if meta.modifier == 'missing'
      throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

    exports.handle = (tbl, metas, value)->
      for m in metas
        unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
          throw new Error("String Search: unsupported type #{JSON.stringify(m)}")
      op = OPERATORS[metas[0].operator]

      unless op
        throw new Error("Token Search: Unsupported operator #{JSON.stringify(metas)}")

      op(tbl, metas, value)

    exports.index = (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_token"

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':GIN'
          on: ['$q', meta.resourceType.toLowerCase()]
          expression: [extract_expr(metas)]
      ]
