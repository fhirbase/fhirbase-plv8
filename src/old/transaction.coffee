plv8 = require('../lib/plv8')
crud = require('./crud')
schema = require('./schema')
bundle = require('../spec/fixtures/transaction_bundle.json')


transaction = (plv8, bundle)->
  for entry in bundle.entry
    # console.log entry.transaction
    switch entry.transaction.method
      when "GET"
        console.log "read resource"
      when "PUT"
        console.log "update resource"
      when "POST"
        crud.create(plv8, entry.resource)
      when "DELETE"
        console.log "destroy resource"
      else
        throw new Error("unsupported method #{entry.transaction.method}")

schema.generate_table(plv8, "Patient")
# schema.generate_table(plv8, "Patient")
# console.log schema.table_exists(plv8, "boo")
transaction(plv8, bundle)
