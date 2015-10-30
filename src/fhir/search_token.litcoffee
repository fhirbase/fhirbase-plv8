# Search and indexing token elements

Handle tokens search queries, extract function and indexing.

This type of search is specified on http://hl7-fhir.github.io/search.html#token.

In extract_as_token is passed resource, path, element_type and returns
array of texts. Different coded types behaviour just hardcoded.

PostgreSQL implementation is based on arrays support - http://www.postgresql.org/docs/9.4/static/arrays.html.


    sql = require('../honey')
    lang = require('../lang')
    xpath = require('./xpath')

    TODO = -> throw new Error("TODO")

    exports.extract_as_token = (plv8, resource, path, element_type)->
      res = []
      data = xpath.get_in(resource, [path])
      if element_type == 'boolean'
        for str in data
          if str.toString() == 'false'
            'false'
          else
            'true'
      else if element_type == 'code' || element_type == 'string'
        str.toString() for str in data
      else if element_type == 'Identifier' or element_type == 'ContactPoint'
        for coding in data
            res.push(coding.value)
            res.push("#{coding.system}|#{coding.value}")
        res
      else if element_type == 'Coding'
        for coding in data
            res.push(coding.code)
            res.push("#{coding.system}|#{coding.code}")
        res
      else if element_type == 'Quantity'
        for quant in data
            res.push(quant.code)
            res.push(quant.unit)
            res.push("#{quant.system}|#{quant.code}")
            res.push("#{quant.system}|#{quant.unit}")
        res
      else if element_type == 'CodeableConcept'
        for concept in data
          for coding in (concept.coding || [])
            res.push(coding.code)
            res.push("#{coding.system}|#{coding.code}")
        res
      else if element_type == 'Reference'
        for ref in data
          res.push(ref.reference)
        res
      else
        throw new Error("extract_as_token: Not implemented for #{element_type}")

    exports.extract_as_token.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'text[]'
      immutable: true


    extract_expr = (meta, tbl)->
      from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

      ['$extract_as_token'
        ['$cast', from, ':json']
        ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
        ['$quote', meta.elementType]]


    OPERATORS =
      eq: (tbl, meta, value)->
        ["$&&"
          ['$cast', extract_expr(meta, tbl), ":text[]"]
          ['$cast', ['$array', value.value], ":text[]"]
          value]

    SUPPORTED_TYPES = [
      'boolean'
      'code'
      'string'
      'CodeableConcept'
      'Coding'
      'ContactPoint'
      'Identifier'
      'Reference'
      'Quantity'
    ]

    handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Token Search: unsuported type #{JSON.stringify(meta)}")

      op = OPERATORS[meta.operator]

      unless op
        throw new Error("Token Search: Unsupported operator #{JSON.stringify(meta)}")

      op(tbl, meta, value)

    exports.handle = handle

    exports.index = (plv8, meta)->
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_token"

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':GIN'
          on: meta.resourceType.toLowerCase()
          expression: extract_expr(meta)
      ]
