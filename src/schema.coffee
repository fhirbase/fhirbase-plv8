generate_tables = (nm)->
  plv8.execute sql(create: "table", name: nm.toLowerCase())
  sql(alter: "table")
