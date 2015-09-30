# schema = require('./src/fhir/schema')
plv8 = require('./plpl/src/plv8')
xpath = require('./src/fhir/xpath.coffee')


# console.log parse("f:DataElement/f:element/f:mapping/f:extension")
# console.log parse("f:DataElement/f:element/f:mapping/f:extension[@url='http://hl7.org/fhir/StructureDefinition/11179-objectClass']")

params = require('./fhir/search-parameters.json')

console.log params.entry.length
console.log xpath

for x in params.entry
  path = x.resource.xpath
  if path && path.match(/\[/)
    console.log 'XPATH', path
    console.log '>'
    console.log "  " + JSON.stringify(xpath.parse(path)) + "\n"
