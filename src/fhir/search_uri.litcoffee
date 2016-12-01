# Search and indexing uri elements

Handle uri search queries, providing *extract* function and *indexing*:

We use string functions to implement uri search (see string_search).

    lang = require('../lang')
    xpath = require('./xpath')
    search_token = require('./search_token')
    search_common = require('./search_common')

    normalize_value = (x)-> x && x.trim().toLowerCase().replace(/^(http:\/\/|https:\/\/|ftp:\/\/)/, '')

    EMPTY_VALUE = "$$NULL"

    identity = (x)-> x

    exports.fhir_extract_as_uri = (plv8, resource, path, element_type)->
      obj = xpath.get_in(resource, [path])
      vals = lang.values(obj).map((x)-> x && x.toString().trim()).filter(identity)

      if vals.length == 0
        EMPTY_VALUE
      else
        ("^^#{normalize_value(v)}$$" for v in vals).join(" ")

    exports.fhir_extract_as_uri.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'text'
      immutable: true

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

    exports.fhir_extract_as_uri_metas = (plv8, resource, metas)->
      value = extract_value(resource, metas)
      if value
        vals = lang.values(value.value).map((x)-> x && x.toString().trim()).filter(identity)
      else
        vals = []

      if vals.length == 0
        EMPTY_VALUE
      else
        ("^^#{normalize_value(v)}$$" for v in vals).join(" ")

    exports.fhir_extract_as_uri_metas.plv8_signature =
      arguments: ['json', 'json']
      returns: 'text'
      immutable: true

    sf = search_common.get_search_functions({extract: 'fhir_extract_as_uri'})
    extract_expr = sf.extract_expr

    OPERATORS =
      eq: (tbl, meta, value)->
        ["$ilike", extract_expr(meta, tbl), "%^^#{normalize_value(value.value)}$$%"]
      below: (tbl, meta, value)->
        ["$ilike", extract_expr(meta, tbl), "%^^#{normalize_value(value.value)}%"]
      missing: (tbl, meta, value)->
        if value.value == 'false'
          ["$ne", extract_expr(meta, tbl), EMPTY_VALUE]
        else
          ["$ilike", extract_expr(meta, tbl), EMPTY_VALUE]

    SUPPORTED_TYPES = ['uri']

    exports.normalize_operator = (meta, value)->
      return 'eq' if not meta.modifier and not value.prefix
      return meta.modifier if OPERATORS[meta.modifier]
      throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

    exports.handle = (tbl, meta, value)->
      if Array.isArray(meta)
        for m in meta
          unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
            throw new Error("Uri Search: unsuported type #{JSON.stringify(m)}")
        op = OPERATORS[meta[0].operator]
      else
        unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
          throw new Error("Uri Search: unsuported type #{JSON.stringify(meta)}")
        op = OPERATORS[meta.operator]

      unless op
        throw new Error("Uri Search: Unsupported operator #{JSON.stringify(meta)}")

      op(tbl, meta, value)

    exports.order_expression = (tbl, meta)->
      search_token.order_expression(tbl, meta)

    exports.index = (plv8, metas)->
      meta = metas[0]
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_uri"
      exprs = metas.map((x)-> extract_expr(x))

      [{
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':GIN'
          opclass: ':gin_trgm_ops'
          on: ['$q', meta.resourceType.toLowerCase()]
          expression: exprs
      },{
        name: idx_name + '_metas'
        ddl:
          create: 'index'
          name:  idx_name + '_metas'
          using: ':GIN'
          opclass: ':gin_trgm_ops'
          on: ['$q', meta.resourceType.toLowerCase()]
          expression: [extract_expr(metas)]
      }]
