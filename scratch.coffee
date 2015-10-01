# schema = require('./src/fhir/schema')
plv8 = require('./plpl/src/plv8')
xpath = require('./src/fhir/xpath.coffee')


# console.log parse("f:DataElement/f:element/f:mapping/f:extension")
# console.log parse("f:DataElement/f:element/f:mapping/f:extension[@url='http://hl7.org/fhir/StructureDefinition/11179-objectClass']")

params = require('./fhir/search-parameters.json')

get_by_path = (node, path)->
  [x, xs...] = path
  value = node[x]
  if xs.lenght == 0
    value




get_by_paths = (resource, paths)->
  res  = []
  for path in paths
    res = res.concat(get_by_path(resource, path))
  res

console.log params.entry.length
console.log xpath

for x in params.entry
  path = x.resource.xpath
  if path && path.match(/\[/)
    console.log 'XPATH', path
    console.log '>'
    console.log "  " + JSON.stringify(xpath.parse(path)) + "\n"
