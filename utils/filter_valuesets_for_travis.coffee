vs = require(__dirname + '/../fhir/valuesets.json')

entries = vs.entry
delete vs.entry

keey_entries = [
  'issue'
  'gender'
]

keeped = []

for entry in entries
  if keey_entries.some((x)-> entry.resource.id.indexOf(x) > -1)
    keeped.push(entry)



vs.entry = keeped


fs = require('fs')

fs.writeFileSync(__dirname + '/../fhir/valuesets-minified.json', JSON.stringify(vs, null, "  "))
