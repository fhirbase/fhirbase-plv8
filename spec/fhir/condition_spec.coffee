search = require('../../src/fhir/search')
honey = require('../../src/honey')
assert = require('assert')


search.condition(
  path: ['name']
  elementType: 'HumanName',
  searchType: 'string'
  multi: true
  operation: 'eq'
  values: ['nicola','ivan']
)

specs = [
 {cond:
    path: ['name']
    elementType: 'HumanName',
    searchType: 'string'
    operation: 'eq'
    value: ['nicola','ivan']
    array: true
  result:
    [':&&'
      {call: 'fhir.extract_as_string_array', args: [':resource', '["name"]', 'HumanName'], cast: 'text[]' }
      {value: ['nicola','ivan'], array:true, cast: 'text[]'}] }
 {cond:
    path: ['active']
    elementType: 'boolean',
    searchType: 'token'
    operation: 'eq'
    value: ['true']
    array: false
  result: [':='
      {call: 'fhir.extract_as_token', args: [':resource', '["active"]', 'boolean'], cast: 'boolean' }
      ':true'
  ]
 }
]


describe "CRUD", ()->
  it "simple", ()->
    for spec in specs
      assert.deepEqual(search.condition(spec.cond), spec.result)
      console.log honey(select: [':*'], from: ['patient'], where: spec.result)


search.search_sql('Patient', 'name=ivan&given=ivanov') => sql
