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

    exports.plv8_schema = "fhir"


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
      else if operator == 'eq'
        ['$tstzrange', date.to_lower_date(value), date.to_upper_date(value), '[)']
      else
        throw new  Error('Unhandled')

    exports.value_to_range = value_to_range

    overlap_expr = (tbl, meta, value)->
      ["$&&"
        ['$cast'
          ['$fhir.extract_as_daterange'
            ['$cast', ['$q',":#{tbl}", ':resource'], ':json']
            ['$json', meta.path]
            meta.elementType]
            "tstzrange"]
        value_to_range(meta.operator, value.value)]

    TODO = -> throw new Error("TODO")

    OPERATORS =
      eq: overlap_expr
      gt: overlap_expr
      ge: overlap_expr
      lt: overlap_expr
      le: overlap_expr
      ne: TODO
      sa: TODO
      eb: TODO
      ap: TODO


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
