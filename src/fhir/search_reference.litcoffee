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

    exports.plv8_schema = "fhir"

    TODO = -> throw new Error("TODO")

    exports.extract_as_reference = (plv8, resource, path, element_type)->
      if element_type == 'Reference'
        res = []
        for ref in xpath.get_in(resource, [path]) when ref and ref.reference
          reference = ref.reference.toLowerCase()
          parts = reference.split('/')
          len = parts.length
          res.push(parts[(len - 1)])
          res.push("#{parts[(len - 2)]}/#{parts[(len - 1)]}")
          res.push(reference) if len > 2
        res
      else
        throw new Error("extract_as_reference: Not implemented for #{element_type}")

    exports.extract_as_reference.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'text[]'
      immutable: true


    reference_eq = (tbl, meta, value)->
      ["$&&"
        ['$cast'
          ['$fhir.extract_as_reference'
            ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
            ['$json', meta.path]
            meta.elementType]
            ":text[]"]
        ['$cast', ['$array', value.value.toLowerCase()], ":text[]"]
        value]


    OPERATORS =
      eq: reference_eq

    SUPPORTED_TYPES = ['Reference']

    handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Reference Search: unsuported type #{JSON.stringify(meta)}")

      op = OPERATORS[meta.operator]

      unless op
        throw new Error("Reference Search: Unsupported operator #{JSON.stringify(meta)}")

      op(tbl, meta, value)

    exports.handle = handle
