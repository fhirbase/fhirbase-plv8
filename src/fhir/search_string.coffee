lang = require('../lang')
sql = require('../honey')
xpath = require('./xpath')

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

extract_expr = (meta, tbl)->
  from = if tbl then ['$q',":#{tbl}", ':resource'] else ':resource'

  ['$extract_as_string'
    ['$cast', from, ':json']
    ['$cast', ['$quote', JSON.stringify(meta.path)], ':json']
    ['$quote', meta.elementType]]

OPERATORS =
  eq: (tbl, meta, value)->
    ["$ilike", extract_expr(meta, tbl), "%^^#{normalize_string_value(value.value)}$$%"]
  sw: (tbl, meta, value)->
    ["$ilike", extract_expr(meta, tbl), "%^^#{normalize_string_value(value.value)}%"]
  ew: (tbl, meta, value)->
    ["$ilike", extract_expr(meta, tbl), "%#{normalize_string_value(value.value)}$$%"]
  co: (tbl, meta, value)->
    ["$ilike", extract_expr(meta, tbl), "%#{normalize_string_value(value.value)}%"]

SUPPORTED_TYPES = [
 'Address'
 'ContactPoint'
 'HumanName'
 'string'
]


OPERATORS_ALIASES =
  exact: 'eq'
  contains: 'co'
  sw: 'sw'
  ew: 'ew'
  startwith: 'sw'
  endwith: 'ew'

exports.normalize_operator = (meta, value)->
  return 'sw' if not meta.modifier and not value.prefix
  op = OPERATORS_ALIASES[meta.modifier]
  return op if op
  throw new Error("Not supported operator #{JSON.stringify(meta)} #{JSON.stringify(value)}")

handle = (tbl, meta, value)->
  unless SUPPORTED_TYPES.indexOf(meta.elementType) > -1
    throw new Error("String Search: unsuported type #{JSON.stringify(meta)}")

  op = OPERATORS[meta.operator]

  unless op
    throw new Error("String Search: Unsupported operator #{JSON.stringify(meta)}")

  op(tbl, meta, value)

exports.handle = handle

exports.index = (plv8, metas)->
  meta = metas[0]
  idx_name = "#{meta.resourceType.toLowerCase()}_#{meta.name.replace('-','_')}_string"

  exprs = metas.map((x)-> extract_expr(x))

  [
    name: idx_name
    ddl:
      create: 'index'
      name:  idx_name
      using: ':GIN'
      on: meta.resourceType.toLowerCase()
      opclass: ':gin_trgm_ops'
      expression: exprs
  ]

