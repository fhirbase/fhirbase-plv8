exports.table_name = (plv8, resource_name)->
  throw new Error("expected resource_name") unless resource_name
  resource_name.toLowerCase()
