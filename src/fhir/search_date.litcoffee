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
    search_common = require('./search_common')
    utils = require('../core/utils')
    sql = require('../honey')


Now we support only simple date data-types - i.e. date, dateTime and instant.

    SUPPORTED_TYPES = [
      'date'
      'dateTime'
      'instant'
      'Period'
      'Timing'
    ]
    sf = search_common.get_search_functions({extract:'fhir_extract_as_daterange', sort:'fhir_sort_as_date',SUPPORTED_TYPES:SUPPORTED_TYPES})
    extract_expr = sf.extract_expr

    exports.order_expression = sf.order_expression
    exports.index_order = sf.index_order

    str = (x)-> x.toString()

Function to extract element from resource as tstzrange.

    exports.fhir_extract_as_daterange = (plv8, resource, path, element_type)->
      if ['date', 'dateTime', 'instant'].indexOf(element_type) > -1
        value = xpath.get_in(resource, [path])[0]
        if value
          date.to_range(value.toString())
        else
          null
      else if element_type == 'Period'
        value = xpath.get_in(resource, [path])[0]
        if value
          lower = date.to_lower_date(value.start)
          upper = if value.end then date.to_upper_date(value.end) else 'infinity'
          "(#{lower}, #{upper}]"
        else
          null
      else
        throw new Error("fhir_extract_as_date: Not implemented for #{element_type}")

    exports.fhir_extract_as_daterange.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'tstzrange'
      immutable: true

    exports.fhir_sort_as_date = (plv8, resource, path, element_type)->
      if ['date', 'dateTime', 'instant'].indexOf(element_type) > -1
        value = xpath.get_in(resource, [path])[0]
        if value
          date.to_lower_date(value.toString())
        else
          null
      else if element_type == 'Period'
        value = xpath.get_in(resource, [path])[0]
        if value
          date.to_lower_date(value.start || value.end)
        else
          null
      else
        throw new Error("fhir_sort_as_date: Not implemented for #{element_type}")

    exports.fhir_sort_as_date.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'timestamptz'
      immutable: true

Function to convert query parameter into range.

    value_to_range = (operator, value)->
      if operator == 'lt'
        ['$tstzrange', '-infinity', date.to_lower_date(value), '()']
      else if operator == 'le'
        ['$tstzrange', '-infinity', date.to_upper_date(value), '()']
      else if operator == 'gt'
        ['$tstzrange', date.to_upper_date(value), 'infinity', '()']
      else if operator == 'ge'
        ['$tstzrange', date.to_lower_date(value), 'infinity', '()']
      else if operator == 'eq' or operator = 'ne'
        ['$tstzrange', date.to_lower_date(value), date.to_upper_date(value), '[)']
      else
        throw new  Error("Do not know how to create daterange for #{operator} #{value}")

    exports.value_to_range = value_to_range

    overlap_expr = (tbl, meta, value)->
      ["$&&", extract_expr(meta), value_to_range(meta.operator, value.value)]

    not_overlap_expr = (tbl, meta, value)->
      ['$not', ["$&&", extract_expr(meta), value_to_range(meta.operator, value.value)]]

    missing_expr = (tbl, meta, value)->
      if value.value == 'false'
        ["$notnull", extract_expr(meta)]
      else
        ["$null", extract_expr(meta)]

    TODO = -> throw new Error("Date search: unimplemented")

    OPERATORS =
      eq: overlap_expr
      gt: overlap_expr
      ge: overlap_expr
      lt: overlap_expr
      le: overlap_expr
      ne: not_overlap_expr
      missing: missing_expr
      # sa: TODO
      # eb: TODO
      # ap: TODO

`normalize operators` every type handle operators normalization

    exports.normalize_operator = (meta, value)->
      if not meta.modifier and not value.prefix
        return 'eq'
      if meta.modifier == 'missing'
        return 'missing'
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
          on: ['$q', tbl]
          expression:  exprs
      ]

Function to extract element from resource as epoch.

    epoch = (plv8, value)->
      if value
        res = utils.exec plv8,
          select: sql.raw("extract(epoch from ('#{value.toString()}')::timestamp at time zone 'UTC')")
        res[0].date_part
      else
        null

    exports.fhir_extract_as_epoch_lower = (plv8, resource, path, element_type)->
      if ['date', 'dateTime', 'instant'].indexOf(element_type) > -1
        value = xpath.get_in(resource, [path])[0]
        value && epoch(plv8, value)
      else if element_type == 'Period'
        value = xpath.get_in(resource, [path])[0]
        value && epoch(plv8, value.start)
      else
        throw new Error("fhir_extract_as_epoch: Not implemented for #{element_type}")

    exports.fhir_extract_as_epoch_lower.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'double precision'
      immutable: true

    exports.fhir_extract_as_epoch_upper = (plv8, resource, path, element_type)->
      if ['date', 'dateTime', 'instant'].indexOf(element_type) > -1
        value = xpath.get_in(resource, [path])[0]
        value && epoch(plv8, value)
      else if element_type == 'Period'
        value = xpath.get_in(resource, [path])[0]
        value && epoch(plv8, value.end)
      else
        throw new Error("fhir_extract_as_epoch: Not implemented for #{element_type}")

    exports.fhir_extract_as_epoch_upper.plv8_signature =
      arguments: ['json', 'json', 'text']
      returns: 'double precision'
      immutable: true
