# Search and indexing uri elements

Handle uri search queries, providing *extract* function and *indexing*:

We use string functions to implement uri search (see string_search).

    lang = require('../lang')
    xpath = require('./xpath')

    exports.plv8_schema = "fhir"

    normalize_value = (x)-> x && x.trim().toLowerCase().replace(/^(http:\/\/|https:\/\/|ftp:\/\/)/, '')

    exports.extract_as_uri = (plv8, resource, path, element_type)->
      obj = xpath.get_in(resource, [path])
      ("^^#{normalize_value(v)}$$" for v in lang.values(obj)).join(" ")

    exports.extract_as_uri.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'text'
      immutable: true

    ilike_expr = (tbl, meta, value)->
      ["$ilike"
        ['$cast'
          ['$fhir.extract_as_uri'
            ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
            ['$json', meta.path]
            meta.elementType]
            "text"]
        value]

    OPERATORS =
      eq: (tbl, meta, value)-> ilike_expr(tbl, meta, "%^^#{normalize_value(value.value)}$$%")
      below: (tbl, meta, value)-> ilike_expr(tbl, meta, "%^^#{normalize_value(value.value)}%")

    SUPPORTED_TYPES = ['uri']

    handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Uri Search: unsuported type #{JSON.stringify(meta)}")

      op = OPERATORS[meta.operator]

      unless op
        throw new Error("Uri Search: Unsupported operator #{JSON.stringify(meta)}")

      op(tbl, meta, value)

    exports.handle = handle
