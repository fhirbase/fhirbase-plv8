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
    search_common = require('./search_common')

    SUPPORTED_TYPES = ['Quantity']
    OPERATORS = ['eq', 'lt', 'le', 'gt', 'ge', 'missing']

    sf = search_common.get_search_functions({
      extract:'fhir_extract_as_number',
      sort:'fhir_extract_as_number',
      SUPPORTED_TYPES:SUPPORTED_TYPES
    })
    exports.index_order = sf.index_order

    identity = (x)-> x

    extract_expr = (metas, tbl)->
      from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'
      m = metas.map((x)-> {path: x.path, elementType: x.elementType})
      ["$fhir_extract_as_#{metas[0].searchType}"
        ['$cast', from, ':json']
        ['$cast', ['$quote', JSON.stringify(m)], ':json']]

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

    exports.handle = (tbl, metas, value)->
      for m in metas
        unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
          throw new Error("String Search: unsupported type #{JSON.stringify(m)}")
        unless OPERATORS.indexOf(m.operator) > -1
          throw new Error("Quantity Search: Unsupported operator #{m.operator}")
      operator = metas[0].operator

      parts = value.value.split('|')
      numeric_part = parts[0]

      op = if operator == 'missing'
          if value.value == 'false' then '$notnull' else '$null'
        else
          "$#{operator}"

      m = metas.map((m)-> assoc(m, 'searchType', 'number'))

      expr = [op, extract_expr(m, tbl), numeric_part]

      if parts.length == 1 or operator == 'missing'
        expr
      else
        token_part = parts[1..-1].filter(identity).join('|')
        m = metas.map((m)-> assoc(m, 'searchType', 'token'))

        ['$and'
          expr
          ["$&&",
            extract_expr(m, tbl),
            ['$cast', ['$array', token_part], ":text[]"]]]

    exports.order_expression = (tbl, metas)->
      m = metas.map((meta)-> assoc(meta, 'searchType', 'number'))
      number_s.order_expression(tbl, m)

    exports.index = (plv8, metas)->
      number_part = number_s.index(plv8, metas.map((meta)-> assoc(meta, 'searchType', 'number')))
      token_part = token_s.index(plv8, metas.map((meta)-> assoc(meta, 'searchType', 'token')))
      number_part.concat(token_part)
