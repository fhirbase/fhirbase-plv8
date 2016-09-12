sql = require('../src/honey')

output = (x)->
  if Array.isArray(x)
    console.log(x[0], ';')
  else
    console.log(x, ';')

VERSION = '1'

is_first = true

for extension in [':pgcrypto', ':plv8', ':pg_trgm']
  output sql({create: 'extension', name: extension, safe: true})

# Patch statements should be below.
