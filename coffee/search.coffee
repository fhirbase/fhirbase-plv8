operators = [
  [/^>=/, 'ge']
  [/^<=/, 'le']
  [/^~/,  'ap']
  [/!=/,  'ne']
  [/^>/,  'gt']
  [/^</,  'lt']
]

modifiers = ['exact', 'missing'].map (m)-> [m, new RegExp(":#{m}$")]

splitOnce = (str, pat)->
  idx = str.indexOf(pat)
  [str.substr(0,idx), str.substr(idx + 1)]

mkChain = (res_type, xs)->
  parts = for x in xs
    throw new Error("fhirbase chain require type #{res_type} #{xs.join('.')}") if x.indexOf(':') < 0
    x.split(':')
  res = []
  for [el,tp] in parts
    res.push {from: res_type, on: el, to: tp}
    res_type = tp
  res

parse_pair = (res_type, x)->
  [k,v] = splitOnce(x, '=')
  op = 'eq'
  for [opre, opn] in operators when v.match(opre)
    op = opn
    v = v.replace(opre,'')
    break
  for [m,mre] in modifiers when k.match(mre)
    op = m
    k = k.replace(mre,'')
    break
  res = {value: v.split(','), key: k, op: op}
  if k.indexOf('.') > -1
     chain = k.split('.')
     res.key = chain[chain.length - 1]
     res.chain = mkChain(res_type, chain[0..-2])
  res

parse_params = (res_type, params)->
  decodeURI(params)
    .split('&')
    .map((x)-> parse_pair(res_type, decodeURIComponent(x)))

exports.parse_params = parse_params

load_parameter = (plv8, resource, name)->
  res = plv8.execute("select path, base, search_type, type, is_primitive from searchparameter where base = $1 and name in ($2)", [resource, name])[0]
  throw new Error("No search param for #{resource} #{name}") unless res
  res

merge = (to,from)->
  to[k] = v for k,v of from
  to

expand_params = (plv8, res_type, params)->
  eparams = []
  for p in params
    unless p.chain
      eparams.push merge(p, load_parameter(plv8, res_type, p.key))
    else
      p.chain = for ch in p.chain
        merge(ch, load_parameter(plv8, ch.from, ch.on))
      last_ch = p.chain[p.chain.length - 1]
      eparams.push merge(p, load_parameter(plv8, last_ch.to, p.key))
  eparams

exports.expand_params = expand_params

joins = (res_type, params)->
  'joins....'

token_idx_fn = (p)->
  if p.is_primitive
    "primitive_as_token"
  else
    "#{p.type.toLowerCase()}_as_token"

CONDITIONS =
  identifier:
    any: (p)->
      "#{p.base}.logical_id IN(#{p.value.join(',')})"
  string:
    eq: (p)->
      "fhirbase_idx_fns.index_as_string(\"#{p.base}\".content, #{p.path}) ilike #{p.value}"
   exact: (p)->
      "fhirbase_idx_fns.index_as_string(\"#{p.base}\".content, #{p.path}) = #{p.value}"
  token:
    eq: (p)->
      "#{token_idx_fn(p)}(#{p.base}.content, #{p.path}) && #{p.value.join(',')}::text[]"
  date:
    any: (p)->
      "fhirbase_date_idx.index_as_date(#{p.base}.content, #{p.path}::text[], #{p.type}) && mkrage TODO"
  reference:
    any: (p)->
      'fhirbase_idx_fns.index_as_reference(content, %L) && %L::text[]'

conditions = (res_type, params)->
  res = for p in params when !p.chain
    cnd = CONDITIONS[p.search_type]
    throw new Error("Not supported type #{p.search_type}") unless cnd
    cndb = cnd[p.op] || cnd.any
    throw new Error("Not supported operation #{p.op}") unless cndb
    cndb(p)
  res.join "\n AND"

search = (plv8, res_type, params)->
  params = parse_params(res_type, params)
  params = expand_params(plv8, res_type, params)
  conds = conditions(res_type, params)
  conds = if conds then "WHERE #{conds}" else ''
  joins = joins(res_type, params)
  """
    SELECT * FROM "#{res_type.toLowerCase()}"
    #{joins} #{conds}
  """
exports.search = search
