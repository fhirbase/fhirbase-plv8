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

    extract_op_expr = (opname, metas)->
      m = metas.map((x)-> {path: x.path, elementType: x.elementType})
      ["$#{opname}"
       ['$cast', ':resource', ':json']
       ['$cast', ['$quote', JSON.stringify(m)], ':json']]

    extract_lower_expr = (metas)->
      extract_op_expr('fhir_extract_as_epoch_lower', metas)

    extract_upper_expr = (metas)->
      extract_op_expr('fhir_extract_as_epoch_upper', metas)

    exports.order_expression = sf.order_expression
    exports.index_order = sf.index_order

    str = (x)-> x.toString()

    epoch = (plv8, value)->
      if value
        res = utils.exec plv8,
          select: sql.raw("extract(epoch from ('#{value.toString()}')::timestamp with time zone)")
        res[0].date_part
      else
        null

    extract_value = (resource, metas)->
      for meta in metas
        value = xpath.get_in(resource, [meta.path])[0]
        if value
          return {
            value: value
            path: meta.path
            elementType: meta.elementType
          }
      null


Function to extract element from resource as tstzrange.

    exports.fhir_sort_as_date = (plv8, resource, metas)->
      value = extract_value(resource, metas)
      if value
        if ['date', 'dateTime', 'instant'].indexOf(value.elementType) > -1
          date.to_lower_date(value.value.toString())
        else if value.elementType == 'Period'
          date.to_lower_date(value.value.start || value.value.end)
        else
          throw new Error("fhir_sort_as_date: Not implemented for #{value.elementType}")
      else
        null

    exports.fhir_sort_as_date.plv8_signature =
      arguments: ['json', 'json']
      returns: 'timestamptz'
      immutable: true

Function to convert query parameter into range.

    value_to_epoch_expr = (value)->
      "extract(epoch from ('#{value.toString()}')::timestamp with time zone)::double precision"

    epoch_sql = (expr, operator, value)->
      sql.raw("#{sql(expr)} #{operator} #{value}")

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

    TODO = -> throw new Error("Date search: unimplemented")

    eq_epoch_expr = (tbl, meta, value)->
      ['$and',
        epoch_sql(extract_lower_expr(meta), '<=', value_to_epoch_expr(date.to_upper_date(value.value))),
        epoch_sql(extract_upper_expr(meta), '>', value_to_epoch_expr(date.to_lower_date(value.value)))]

    gt_epoch_expr = (tbl, meta, value)->
      epoch_sql(extract_upper_expr(meta), '>', value_to_epoch_expr(date.to_upper_date(value.value)))

    ge_epoch_expr = (tbl, meta, value)->
      epoch_sql(extract_upper_expr(meta), '>=', value_to_epoch_expr(date.to_lower_date(value.value)))

    lt_epoch_expr = (tbl, meta, value)->
      epoch_sql(extract_lower_expr(meta), '<', value_to_epoch_expr(date.to_lower_date(value.value)))

    le_epoch_expr = (tbl, meta, value)->
      epoch_sql(extract_lower_expr(meta), '<', value_to_epoch_expr(date.to_upper_date(value.value)))

    ne_epoch_expr = (tbl, meta, value)->
      ['$not', eq_epoch_expr(tbl, meta, value)]

    missing_epoch_expr = (tbl, meta, value)->
      expr = ['$and',
        ["$null", extract_lower_expr(meta)],
        ["$null", extract_upper_expr(meta)]]
      if value.value == 'false'
        ["$not", expr]
      else
        expr

    OPERATORS =
      eq: eq_epoch_expr
      gt: gt_epoch_expr
      ge: ge_epoch_expr
      lt: lt_epoch_expr
      le: le_epoch_expr
      ne: ne_epoch_expr
      missing: missing_epoch_expr
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

    handle = (tbl, metas, value)->
      # FIXME: this check doesn't work for polymorphic[x]
      # attributes. We need to fix it somehow here and
      # in all other places. For now it breaks Narus backend, it uses
      # CarePlan.activitydate search param.

      # for m in metas
      #   unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
      #     throw new Error("String Search: unsupported type #{JSON.stringify(m)}")

      op = OPERATORS[metas[0].operator]

      unless op
        throw new Error("Date Search: Unsupported operator #{JSON.stringify(metas)}")

      op(tbl, metas, value)

    exports.handle = handle

    exports.index = (plv8, metas)->
      meta = metas[0]
      tbl = meta.resourceType.toLowerCase()
      idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}"
      lower_exprs = extract_lower_expr(metas)
      upper_exprs = extract_upper_expr(metas)

      [{
       name: "#{idx_name}_epoch_lower_upper"
       ddl:
         create: 'index'
         name: "#{idx_name}_epoch_lower_upper"
         on: ['$q', tbl]
         expression: [lower_exprs, upper_exprs]
      }
      {
       name: "#{idx_name}_epoch_upper_lower"
       ddl:
         create: 'index'
         name: "#{idx_name}_epoch_upper_lower"
         on: ['$q', tbl]
         expression: [upper_exprs, lower_exprs]
      }]

Function to extract element from resource as epoch.

    exports.fhir_extract_as_epoch_lower = (plv8, resource, metas)->
      value = extract_value(resource, metas)
      if value
        if ['date', 'dateTime', 'instant'].indexOf(value.elementType) > -1
          epoch(plv8, date.to_lower_date(value.value))
        else if value.elementType == 'Period'
          epoch(plv8, date.to_lower_date(value.value.start))
        else
          throw new Error("fhir_extract_as_epoch: Not implemented for #{value.elementType}")
      else
        null

    exports.fhir_extract_as_epoch_lower.plv8_signature =
      arguments: ['json', 'json']
      returns: 'double precision'
      immutable: true

    exports.fhir_extract_as_epoch_upper = (plv8, resource, metas)->
      value = extract_value(resource, metas)
      if value
        if ['date', 'dateTime', 'instant'].indexOf(value.elementType) > -1
          epoch(plv8, date.to_upper_date(value.value))
        else if value.elementType == 'Period'
          epoch(plv8, date.to_upper_date(value.value.end))
        else
          throw new Error("fhir_extract_as_epoch: Not implemented for #{value.elementType}")
      else
        null

    exports.fhir_extract_as_epoch_upper.plv8_signature =
      arguments: ['json', 'json']
      returns: 'double precision'
      immutable: true
