schema = require('./src/fhir/schema')
plv8 = require('./plpl/src/plv8')

console.log schema.drop_table(plv8, 'User')
console.log schema.create_table(plv8, 'User')

console.log schema.describe_table(plv8, 'User')
