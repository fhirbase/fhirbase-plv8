idx = require('../../src/fhir/indexing')
test = require('../helpers.coffee')

specs = test.loadYaml("#{__dirname}/xpath_spec.yaml", 'utf8')
pt = specs.patient

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
