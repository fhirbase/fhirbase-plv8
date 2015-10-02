search = require('../../src/fhir/search')


search.condition(
  path: ['name']
  elementType: 'HumanName',
  searchType: 'string'
  multi: true
  operation: 'eq'
  values: ['nicola','ivan']
)

['&&'
  {call: 'extract_as_string_array', args: [':resource', '["name"]', 'HumanName'], cast: 'text[]' }
  {value: ['nicola','ivan'], array:true, cast: 'text[]'}]

['&&',
  "^extract_as_string_array(resource, '[\"name\"]','HumanName')::text[]",
  "ARRAY[$1,$2]::text[]"]

=> "extract_as_string_array(resource, '[\"name\"]','HumanName') && ARRAY['nicola','ivan']::text[]



