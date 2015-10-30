lang = require('../lang')
sql = require('../honey')
xpath = require('./xpath')

exports.plv8_schema = "fhir"

UNACCENT_MAP =
  'é': 'e'
  'á': 'a'
  'ű': 'u'
  'ő': 'o'
  'ú': 'u'
  'ö': 'o'
  'ü': 'u'
  'ó': 'o'
  'í': 'i'
  'É': 'E'
  'Á': 'A'
  'Ű': 'U'
  'Ő': 'O'
  'Ú': 'U'
  'Ö': 'O'
  'Ü': 'U'
  'Ó': 'O'
  'Í': 'I'
  'ò': 'o'

UNACCENT_RE = new RegExp("[" + (k for k,_ of UNACCENT_MAP).join('') + "]" , 'g');
unaccent_fn = (match) -> UNACCENT_MAP[match]

unaccent = (s) -> s.toString().replace(UNACCENT_RE, unaccent_fn)
exports.unaccent = unaccent

TODO = -> throw new Error("TODO")

exports.extract_as_string = (plv8, resource, path, element_type)->
  obj = xpath.get_in(resource, [path])
  ("^^#{unaccent(v)}$$" for v in lang.values(obj)).join(" ")

exports.extract_as_string.plv8_signature =
  arguments: ['json', 'json', 'text']
  returns: 'text'
  immutable: true

normalize_string_value = (x)->
  x && x.trim().toLowerCase()

extract_fn_expr = (meta, tbl)->
  from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

  ['$fhir.extract_as_string'
    ['$cast', from, ':json']
    ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
    ['$quote', meta.elementType]]

OPERATORS =
  eq: (tbl, meta, value)->
    ["$ilike", extract_fn_expr(meta, tbl), "%^^#{normalize_string_value(value.value)}$$%"]
  sw: (tbl, meta, value)->
    ["$ilike", extract_fn_expr(meta, tbl), "%^^#{normalize_string_value(value.value)}%"]
  ew: (tbl, meta, value)->
    ["$ilike", extract_fn_expr(meta, tbl), "%#{normalize_string_value(value.value)}$$%"]
  co: (tbl, meta, value)->
    ["$ilike", extract_fn_expr(meta, tbl), "%#{normalize_string_value(value.value)}%"]

SUPPORTED_TYPES = [
 'Address'
 'ContactPoint'
 'HumanName'
 'string'
]

handle = (tbl, meta, value)->
  unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
    throw new Error("String Search: unsuported type #{JSON.stringify(meta)}")

  op = OPERATORS[meta.operator]

  unless op
    throw new Error("String Search: Unsupported operator #{JSON.stringify(meta)}")

  op(tbl, meta, value)

exports.handle = handle

exports.index = (plv8, meta)->
  idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_string"

  name: idx_name
  ddl:
    create: 'index'
    name:  idx_name
    using: ':GIN'
    on: meta.resourceType.toLowerCase()
    opclass: ':gin_trgm_ops'
    expression: extract_fn_expr(meta)

