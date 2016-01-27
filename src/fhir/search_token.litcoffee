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

    exports.fhir_extract_as_token = (plv8, resource, path, element_type)->
      res = []
      data = xpath.get_in(resource, [path])

      if element_type == 'boolean'
        res = for str in data
          if str.toString() == 'false'
            'false'
          else
            'true'
      else if element_type == 'dateTime' or element_type == 'date'
        res = if data.length > 0 then ['true', 'false'] else []
      else if element_type == 'code' || element_type == 'string' || element_type == 'uri'
        res = (str.toString() for str in data)
      else if element_type == 'Identifier' or element_type == 'ContactPoint'
        for coding in data
            res.push(coding.value.toString().toLowerCase()) if coding.value
            res.push("#{coding.system}|#{coding.value}".toLowerCase())
      else if element_type == 'Coding'
        for coding in data
            res.push(coding.code.toString().toLowerCase()) if coding.code
            res.push("#{coding.system}|#{coding.code}".toLowerCase())
      else if element_type == 'Quantity'
        for quant in data
            res.push(quant.code.toString().toLowerCase()) if quant.code
            res.push(quant.unit.toString().toLowerCase()) if quant.unit
            res.push("#{quant.system}|#{quant.code}".toLowerCase())
            res.push("#{quant.system}|#{quant.unit}".toLowerCase())
      else if element_type == 'CodeableConcept'
        for concept in data
          for coding in (concept.coding || [])
            res.push(coding.code.toString().toLowerCase()) if coding.code
            res.push("#{coding.system}|#{coding.code}".toLowerCase())
      else if element_type == 'Reference'
        for ref in data
          res.push(ref.reference)
      else
        throw new Error("fhir_extract_as_token: Not implemented for #{element_type}")

      # console.log("!!!! #{resource.id} #{JSON.stringify(data)} #{JSON.stringify(path)} => #{JSON.stringify(res)} (#{element_type})")


      if res.length == 0
        ['$NULL']
      else
        res

    exports.fhir_extract_as_token.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'text[]'
      immutable: true

    exports.fhir_sort_as_token = (plv8, resource, path, element_type)->
      data = xpath.get_in(resource, [path])[0]
      return null unless data
      if element_type == 'boolean'
        if data.toString() == 'false' then 'false' else 'true'
      else if element_type == 'code' || element_type == 'string' || element_type == 'uri'
        data.toString()
      else if element_type == 'Identifier' or element_type == 'ContactPoint'
        [data.system, data.value].join('0').toLowerCase()
      else if element_type == 'Coding'
        [data.system, data.code, data.display].join('0').toLowerCase()
      else if element_type == 'Quantity'
        [data.system, data.unit, data.code].join('0').toLowerCase()
      else if element_type == 'CodeableConcept'
        coding = data.coding && data.coding[0]
        if coding
          [coding.system, coding.code, coding.display].join('0').toLowerCase()
        else
          data.text || JSON.stringify(data)
      else if element_type == 'Reference'
        data.reference
      else
        throw new Error("fhir_extract_as_token: Not implemented for #{element_type}")

    exports.fhir_sort_as_token.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'text'
      immutable: true

    OPERATORS =
      missing: (tbl, meta, value)->
        op = if value.value == 'false' then '$ne' else '$eq'
        [op
          ['$cast', extract_expr(meta, tbl), ":text[]"]
          ['$cast', ['$array', "$NULL"], ":text[]"]]

      eq: (tbl, meta, value)->
        ["$&&"
          ['$cast', extract_expr(meta, tbl), ":text[]"]
          ['$cast', ['$array', value.value.toString().toLowerCase()], ":text[]"]]


    exports.normalize_operator = (meta, value)->
      return 'eq' if not meta.modifier and not value.prefix
      return 'missing' if meta.modifier == 'missing'
      throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

    exports.handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Token Search: unsupported type #{JSON.stringify(meta)}")

      op = OPERATORS[meta.operator]

      unless op
        throw new Error("Token Search: Unsupported operator #{JSON.stringify(meta)}")

      op(tbl, meta, value)

    exports.index = (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_token"
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
