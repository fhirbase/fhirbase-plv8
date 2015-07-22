params = ()->

util = require('./util')

xpath2array = (xpath)->
  for e in xpath.split('/')
    e.split('f:')[1]

find_parameter = (plv8,resource_type, name)->
  res = plv8.execute """
    select content
      from searchparameter
     where  content->>'base' = $1
       and content->>'name' = $2
   """, [resource_type, name]
  JSON.parse(res[0].content) if res[0]

find_definition = (plv8, resource_type)->
  res = plv8.execute('select content from structuredefinition where logical_id = $1', [resource_type])
  JSON.parse(res[0].content) if res[0]

index_definition = (def)->
  idx = {}
  for el in def.snapshot.element
    idx[el.path] = el
  idx

cache_param_meta = (plv8, param)->
  #console.log('cache_param_meta',param)
  def = find_definition(plv8, param.base)
  unless def
    return {resourceType: "OperationOutcome", message: "No StructureDefinition for #{param.base}"}
  idx = index_definition(def)
  param.path = xpath2array(param.xpath)
  param.element = idx[param.path.join('.')]
  plv8.execute """
    UPDATE searchparameter
    SET content = $1
    WHERE logical_id = $2
    """, [JSON.stringify(param), param.id]
  param

search_sql = (plv8, resource_type, name, value)->
  param = find_parameter(plv8, resource_type, name)
  # laizy cache
  unless param.element
    param = cache_param_meta(plv8, param)

  table_name = util.table_name(param.base)

  etype = param.element.type[0].code.toLowerCase()
  cond  = "idx_#{etype}_as_#{param.type}(content::json, '#{param.path.join('.')}') ilike $1"
  """select * from #{table_name} where #{cond}"""

search_sql.plv8 = 'fhir.search_sql(resource_type text, name text, value text) returns json'
exports.search_sql = search_sql

search = (plv8, resource_type, name, value)->
  plv8.execute(
    search_sql(plv8, resource_type, name, value),
    ["%#{value}%"]
  ).map((x)-> x.content)

search.plv8 = 'fhir.search(resource_type text, name text, value text) returns json'
exports.search = search
