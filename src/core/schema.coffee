sql =  require('../honey')
namings = require('./namings')
utils = require('./utils')
pg_meta = require('./pg_meta')
outcome = require('../fhir/outcome')

fhir_create_storage_sql = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, resource_type)
  constraints = [
    [":ALTER COLUMN resource SET NOT NULL"]
    [":ALTER COLUMN resource_type SET DEFAULT", sql.inlineString(resource_type)]
  ]

  [
    {
      create: "table"
      name: sql.q(nm)
      inherits: [sql.q('resource')]
    }
    {
      alter: "table"
      name: sql.q(nm)
      action:[
        [":ADD PRIMARY KEY (id)"]
        [":ALTER COLUMN created_at SET NOT NULL"]
        [":ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP"]
        [":ALTER COLUMN updated_at SET NOT NULL"]
        [":ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP"]
      ].concat(constraints)
    }
    {
      create: "table"
      name: sql.q(hx_nm)
      inherits:  [sql.q('resource_history')]
    }
    {
      alter: "table"
      name: sql.q(hx_nm)
      action:[
        [":ADD PRIMARY KEY (version_id)"]
        [":ALTER COLUMN valid_from SET NOT NULL"]
        [":ALTER COLUMN valid_to SET NOT NULL"]
      ].concat(constraints)
    }
  ].map(sql).join(";\n")


exports.fhir_create_storage_sql = fhir_create_storage_sql
exports.fhir_create_storage_sql.plv8_signature = ['json', 'json']

# TODO: rename to create_storage
fhir_create_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  if pg_meta.table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} already exists"}
  else
    plv8.execute(fhir_create_storage_sql(plv8, query)) 
    {status: 'ok', message: "Table #{nm} was created"}

exports.fhir_create_storage = fhir_create_storage
exports.fhir_create_storage.plv8_signature = ['json', 'json']

exports.fhir_create_all_storages = (plv8)->
  resourceTypes = pg_meta.resource_types_list(plv8)

  for resourceType in resourceTypes
    fhir_create_storage(plv8, resourceType: resourceType)

  resourceTypes

exports.fhir_create_all_storages.plv8_signature = {
  arguments: 'json'
  returns: 'SETOF text'
  immutable: false
}

fhir_drop_storage_sql = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)
  [
   {drop: "table", name: sql.q(nm), safe: true}
   {drop: "table", name: sql.q(hx_nm), safe: true}
  ].map(sql).join(";\n")

exports.fhir_drop_storage_sql = fhir_drop_storage_sql
exports.fhir_drop_storage_sql.plv8_signature = ['json', 'json']

fhir_drop_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  unless pg_meta.table_exists(plv8, nm)
    {status: 'error', message: "Table #{nm} not exists"}
  else
    plv8.execute(fhir_drop_storage_sql(plv8, query))
    {status: 'ok', message: "Table #{nm} was dropped"}

exports.fhir_drop_storage = fhir_drop_storage
exports.fhir_drop_storage.plv8_signature = ['json', 'json']

exports.fhir_drop_all_storages = (plv8)->
  resourceTypes = pg_meta.resource_types_list(plv8)
    .filter((resourceType)->
      [
        'CodeSystem',
        'ConceptMap',
        'NamingSystem',
        'OperationDefinition',
        'Resource',
        'SearchParameter',
        'StructureDefinition',
        'ValueSet'
      ].indexOf(resourceType) == -1
    )

  for resourceType in resourceTypes
    fhir_drop_storage(plv8, resourceType: resourceType)

  resourceTypes

exports.fhir_drop_all_storages.plv8_signature = {
  arguments: 'json'
  returns: 'SETOF text'
  immutable: false
}

exports.fhir_describe_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)
  columns = utils.exec plv8,
    select: [sql.key('column_name'), sql.key('dtd_identifier')]
    from: sql.q('information_schema','columns')
    where: {table_name: nm , table_schema: utils.current_schema(plv8)}

  name: nm
  columns: columns.reduce(((acc, x)-> acc[x.column_name] = x; delete x.column_name; acc),{})

exports.fhir_describe_storage.plv8_signature = ['json', 'json']

exports.fhir_truncate_storage = (plv8, query)->
  resource_type = query.resourceType
  nm = namings.table_name(plv8, resource_type)
  hx_nm = namings.history_table_name(plv8, nm)

  if pg_meta.table_exists(plv8, nm)
    utils.exec(plv8, truncate: sql.q(nm))
    utils.exec(plv8, truncate: sql.q(hx_nm))
    outcome.truncate_storage_done(resource_type)
  else
    outcome.unknown_type(resource_type)

exports.fhir_truncate_storage.plv8_signature = ['json', 'json']
