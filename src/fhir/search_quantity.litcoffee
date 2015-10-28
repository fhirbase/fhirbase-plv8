# Search and indexing quantity elements

Handle quantitys search queries, extract function and indexing.

This type of search is specified on http://hl7-fhir.github.io/search.html#quantity.

Search by quantity is tricky case, because we need to take into account units.

Now this implementation going go handle units and numbers separately:
work with units as with tokens nd with numbers as with number.

So query like value=le11||mg  will be translated into following expression:

```
extract_number(resource, path, 'Quantity') OP number AND extract_token(resource, path, 'Quantity') &&  ['|mg']
```

TODO: later we will add some support for units convertion and search in canonical form


    SUPPORTED_TYPES = ['Quantity']
    OPERATORS = ['eq', 'lt', 'le', 'gt', 'ge']

    identity = (x)-> x

    handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Quantity Search: unsuported type #{JSON.stringify(meta)}")

      unless OPERATORS.indexOf(meta.operator) > -1
        throw new Error("Quantity Search: Unsupported operator #{meta.operator}")

      parts = value.value.split('|')
      numeric_part = parts[0]

      expr = 
        ["$#{meta.operator}"
          ['$fhir.extract_as_number'
            ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
            ['$json', meta.path]
            'Quantity']
          numeric_part]
      if parts.length  == 1
        expr
      else
        token_part = parts[1..-1].filter(identity).join('|')
        ['$and'
          expr
          ["$&&"
            ['$fhir.extract_as_token'
              ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
              ['$json', meta.path]
              'Quantity']
            ['$cast', ['$array', token_part], ":text[]"]]]

    exports.handle = handle
