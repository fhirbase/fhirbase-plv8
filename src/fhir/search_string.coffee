lang = require('../lang')
sql = require('../honey')
xpath = require('./xpath')
search_common = require('./search_common')
unaccent = require('../unaccent').unaccent
exports.unaccent = unaccent

TODO = -> throw new Error("TODO")

EMPTY_VALUE = "$NULL"

INDEXABLE_ATTRIBUTES =
  HumanName: ['family', 'given', 'prefix', 'suffix', 'text']

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

exports.fhir_extract_as_string = (plv8, resource, metas)->
  value = extract_value(resource, metas)
  vals = []

  if value
    if INDEXABLE_ATTRIBUTES[value.elementType]
      collectValsFn = (o) ->
        result = []
        for k, v of o
          if INDEXABLE_ATTRIBUTES[value.elementType].indexOf(k) >= 0
            if Array.isArray(v)
              result = result.concat(v)
            else
              result.push(v)
        result

      if Array.isArray(value.value)
        for v in value.value
          vals = vals.concat(collectValsFn(v))
      else
        vals = collectValsFn(value.value)
    else
      vals = lang.values(value.value)

  vals = vals.filter((x)-> x && x.toString().trim().length > 0)

  if vals.length == 0
    EMPTY_VALUE
  else
    ("^^#{unaccent(v.toString())}$$" for v in vals).join(" ")

exports.fhir_extract_as_string.plv8_signature =
  arguments: ['json', 'json']
  returns: 'text'
  immutable: true

exports.fhir_sort_as_string = (plv8, resource, metas)->
  value = extract_value(resource, metas)
  return null unless value
  obj = value.value[0]

  res = switch value.elementType
    when 'string'
      obj.toString().toLowerCase()
    when 'HumanName'
      result = []
      for k in INDEXABLE_ATTRIBUTES["HumanName"]
        v = obj[k]
        if v
          if Array.isArray(v)
            result = result.concat(v)
          else
            result.push(v)

      result.join('0')
    when 'Coding'
      [obj.system, obj.code, obj.display].join('0')
    when 'Address'
      [obj.country, obj.city, obj.state, obj.district, [].concat(obj.line || []).join('0'), obj.postalCode, obj.text].join('0')
    when 'ContactPoint'
      [obj.system, obj.value].join('0')
    when 'CodeableConcept'
      coding = obj.coding && obj.coding[0]
      if coding
        [coding.system, coding.code, coding.display, obj.text].join('0')
      else
        obj.text
    else
      lang.values(obj).filter((x)-> x && x.toString().trim()).join('0')

  res && res.toLowerCase()

exports.fhir_sort_as_string.plv8_signature =
  arguments: ['json', 'json']
  returns: 'text'
  immutable: true

normalize_string_value = (x)->
  x && unaccent(x.trim().toLowerCase().toString())

SUPPORTED_TYPES = [
  'Address'
  'ContactPoint'
  'HumanName'
  'string'
]

sf = search_common.get_search_functions({extract:'fhir_extract_as_string', sort:'fhir_sort_as_string',SUPPORTED_TYPES:SUPPORTED_TYPES})
extract_expr = sf.extract_expr

exports.order_expression = sf.order_expression
exports.index_order = sf.index_order

OPERATORS =
  eq: (tbl, metas, value)->
    ["$ilike", extract_expr(metas, tbl), "%^^#{normalize_string_value(value.value)}$$%"]
  sw: (tbl, metas, value)->
    ["$ilike", extract_expr(metas, tbl), "%^^#{normalize_string_value(value.value)}%"]
  ew: (tbl, metas, value)->
    ["$ilike", extract_expr(metas, tbl), "%#{normalize_string_value(value.value)}$$%"]
  co: (tbl, metas, value)->
    ["$ilike", extract_expr(metas, tbl), "%#{normalize_string_value(value.value)}%"]
  missing: (tbl, metas, value)->
    if value.value == 'false'
      ["$ne", extract_expr(metas, tbl), EMPTY_VALUE]
    else
      ["$ilike", extract_expr(metas, tbl), EMPTY_VALUE]

OPERATORS_ALIASES =
  exact: 'eq'
  contains: 'co'
  sw: 'sw'
  ew: 'ew'
  startwith: 'sw'
  endwith: 'ew'
  missing: 'missing'

exports.normalize_operator = (meta, value)->
  return 'sw' if not meta.modifier and not value.prefix
  op = OPERATORS_ALIASES[meta.modifier]
  return op if op
  throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

handle = (tbl, metas, value)->
  for m in metas
    unless SUPPORTED_TYPES.indexOf(m.elementType) > -1
      throw new Error("String Search: unsupported type #{JSON.stringify(m)}")
  op = OPERATORS[metas[0].operator]

  unless op
    throw new Error("String Search: Unsupported operator #{JSON.stringify(metas)}")

  op(tbl, metas, value)

exports.handle = handle

exports.index = (plv8, metas)->
  meta = metas[0]
  idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_string"

  [
    name: idx_name
    ddl:
      create: 'index'
      name:  idx_name
      using: ':GIN'
      on: ['$q', meta.resourceType.toLowerCase()]
      opclass: ':gin_trgm_ops'
      expression: [extract_expr(metas)]
  ]
