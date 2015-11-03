# Search and indexing date elements

Handle date search queries, providing *extract* function and *indexing*:

Most of job is done using PostgreSQL timestamp ranges [tstzranges](http://www.postgresql.org/docs/9.4/static/functions-range.html).
For example to search Patient with birth date more then 1980:

* we convert birth date into range 1996 -> [1996-01-01, 1997-01-01), where `[]` depicts inclusive boundaries and `()` exclusive
* convert parameter 1980 into range with infinity -> [1980-01-01, infinity)
* and test for range intersection using operator `&&`

```sql

to_range(resource.birthDate) && '(1980-01-01, infinity]'::tstzrange

```

This conversions is extracted into [date module](date.coffee).

See it for more details.


    date = require('./date')
    xpath = require('./xpath')


Now we support only simple date data-types - i.e. date, dateTime and instant.

    SUPPORTED_TYPES = [
      'date'
      'dateTime'
      'instant'
      'Period'
      'Timing'
    ]

    str = (x)-> x.toString()

Function to extract element from resource as tstzrange. 

    exports.extract_as_daterange = (plv8, resource, path, element_type)->
      if ['date', 'dateTime', 'instant'].indexOf(element_type) > -1
        value = xpath.get_in(resource, [path]).map(str)
        date.to_range(value) if value
      else if element_type == 'Period'
        value = xpath.get_in(resource, [path])[0]
        lower = date.to_lower_date(value.start)
        upper = if value.end then date.to_upper_date(value.end) else 'infinity'
        "(#{lower}, #{upper}]"
      else
        throw new Error("extract_as_date: Not implemented for #{element_type}")

    exports.extract_as_daterange.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'tstzrange'
      immutable: true

Function to convert query parameter into range.

    value_to_range = (operator, value)->
      if operator == 'lt' || operator == 'le'
        ['$tstzrange', '-infinity', date.to_upper_date(value), '()']
      else if operator == 'gt' || operator == 'ge'
        ['$tstzrange', date.to_lower_date(value), 'infinity', '[)']
      else if operator == 'eq' or operator = 'ne'
        ['$tstzrange', date.to_lower_date(value), date.to_upper_date(value), '[)']
      else
        throw new  Error("Do not know how to create daterange for #{operator} #{value}")

    exports.value_to_range = value_to_range

    extract_expr = (meta, tbl)->
      from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

      ['$extract_as_daterange'
        ['$cast', from, ':json']
        ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
        ['$quote', meta.elementType]]

    overlap_expr = (tbl, meta, value)->
      ["$&&", extract_expr(meta), value_to_range(meta.operator, value.value)]

    not_overlap_expr = (tbl, meta, value)->
      ['$not', ["$&&", extract_expr(meta), value_to_range(meta.operator, value.value)]]

    TODO = -> throw new Error("Date search: unimplemented")

    OPERATORS =
      eq: overlap_expr
      gt: overlap_expr
      ge: overlap_expr
      lt: overlap_expr
      le: overlap_expr
      ne: not_overlap_expr
      # sa: TODO
      # eb: TODO
      # ap: TODO

`normalize operators` every type handle operators normalization

    exports.normalize_operator = (meta, value)->
      if not meta.modifier and not value.prefix
        return 'eq'
      if OPERATORS[value.prefix]
        return value.prefix
      throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")


`handle` is implementation of search interface for date types.
It is passed table name, meta {operator: 'lt,gt,eq', path: ['Patient', 'birthDate']}, query parameter value
and returns honeysql expression.


    handle = (tbl, meta, value)->
      unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
        throw new Error("Date Search: unsuported type #{JSON.stringify(meta)}")

      op = OPERATORS[meta.operator]

      unless op
        throw new Error("Date Search: Unsupported operator #{JSON.stringify(meta)}")

      op(tbl, meta, value)

    exports.handle = handle

    exports.index = (plv8, metas)->
      meta = metas[0]
      tbl = meta.resourceType.toLowerCase()
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_date"
      exprs = metas.map((x)-> extract_expr(x))

      [
        name: idx_name
        ddl:
          create: 'index'
          name:  idx_name
          using: ':GIST'
          opclass: ':range_ops'
          on: tbl
          expression:  exprs
      ]
