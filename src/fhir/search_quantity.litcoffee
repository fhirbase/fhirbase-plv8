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


    lang = require('../lang')

    token_s = require('./search_token')
    number_s = require('./search_number')

    SUPPORTED_TYPES = ['Quantity']
    OPERATORS = ['eq', 'lt', 'le', 'gt', 'ge', 'missing']

    identity = (x)-> x

    extract_expr = (meta, tbl)->
      from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

      ["$extract_as_#{meta.searchType}"
        ['$cast', from, ':json']
        ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
        ['$quote', meta.elementType]]

    assoc = (obj, k, v)->
      res = lang.clone(obj)
      res[k] = v
      res

    exports.normalize_operator = (meta, value)->
      if not meta.modifier and not value.prefix
        return 'eq'
      if meta.modifier == 'missing'
        return 'missing'
      if OPERATORS.indexOf(value.prefix) > -1
        return value.prefix
      throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

    exports.handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Quantity Search: unsuported type #{JSON.stringify(meta)}")

      unless OPERATORS.indexOf(meta.operator) > -1
        throw new Error("Quantity Search: Unsupported operator #{meta.operator}")

      parts = value.value.split('|')
      numeric_part = parts[0]

      op = if meta.operator == 'missing'
          if value.value == 'false' then '$notnull' else '$null'
        else
          "$#{meta.operator}"

      expr = [op, extract_expr(assoc(meta, 'searchType', 'number'), tbl), numeric_part]

      if parts.length  == 1 or meta.operator == 'missing'
        expr
      else
        token_part = parts[1..-1].filter(identity).join('|')
        meta.searchType = 'token'
        ['$and'
          expr
          ["$&&",
            extract_expr(assoc(meta, 'searchType', 'token'), tbl),
            ['$cast', ['$array', token_part], ":text[]"]]]

    exports.index = (plv8, metas)->
      number_part = number_s.index(plv8, metas.map((meta)-> assoc(meta, 'searchType', 'number')))
      token_part = token_s.index(plv8, metas.map((meta)-> assoc(meta, 'searchType', 'token')))
      number_part.concat(token_part)
