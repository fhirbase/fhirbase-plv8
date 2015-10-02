idx = require('../../src/fhir/indexing')

yaml = require('js-yaml')
fs   = require('fs')

pt = yaml.safeLoad(fs.readFileSync("#{__dirname}/pt.yaml", 'utf8'))

console.log idx.extract(pt,
  path: [['identifier', 'value']]
  searchType: 'string'
  elementType: 'string'
)

console.log idx.extract(pt,
  path: [['gender']]
  searchType: 'token'
  elementType: 'code'
)

console.log idx.extract(pt,
  path: [['name','given']]
  searchType: 'string'
  elementType: 'string'
)

console.log idx.extract(pt,
  path: [['birthDate']]
  elementType: 'date'
  searchType: 'date'
)

console.log idx.extract(pt,
  path: [['name']]
  elementType: 'HumanName'
  searchType: 'string'
)

console.log idx.extract(pt,
  path: [['address']]
  elementType: 'Address'
  searchType: 'string'
)
