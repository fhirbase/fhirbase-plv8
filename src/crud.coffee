util = require('./util')
uuid = (plv8)->
  plv8.execute('select gen_random_uuid() as uuid')[0].uuid

exports.uuid = uuid

load_bundle = (plv8, bundle)->

create = (plv8, resource)->
  # TODO check for resource table
  resource_type = resource.resourceType
  table_name = util.table_name(resource_type)
  logical_id = resource.id || uuid(plv8)
  resource.id = logical_id
  version_id = (resource.meta && resource.meta.versionId) ||  uuid(plv8)
  resource.meta ||= {}
  resource.meta.versionId = version_id
  json  = JSON.stringify(resource)

  res = plv8.execute """
    INSERT INTO #{table_name}
    (logical_id, version_id, content)
    VALUES ($1,$2,$3)
    """, [logical_id, version_id, json]
  resource

exports.create = create
exports.create.plv8 ='fhir.create(resource json) returns json'

load_bundle = (plv8, bundle)->
  for dt in bundle.entry
    create(plv8, dt.resource)

exports.load_bundle = load_bundle

read = (plv8, rt, logical_id)->
  res = plv8.execute """
    SELECT content
      FROM #{util.table_name(rt)}
     WHERE logical_id = $1
   """, [logical_id]

  if res.length == 1
    return JSON.parse(res[0].content)
  else
    {resourceType: 'OperationOutcome', message: 'Not found'}

read.plv8 = 'fhir.read(rt text, logical_id text) returns json'
exports.read = read

vread = (plv8, rt, version_id)->
  table_name = util.table_name(rt)
  res = plv8.execute """
    SELECT content
      FROM "#{table_name}_history"
     WHERE version_id = $1
   """, [version_id]
  unless res[0]
    res = plv8.execute """
      SELECT content
        FROM "#{table_name}"
       WHERE version_id = $1
     """, [version_id]
  if res.length == 1
    return JSON.parse(res[0].content)
  else
    {resourceType: 'OperationOutcome'}

vread.plv8 = 'fhir.vread(rt text, version_id text) returns json'
exports.vread = vread

destroy = (plv8, rt, logical_id)->
  table_name = util.table_name(rt)
  resource = read(plv8, rt, logical_id)
  plv8.execute """DELETE FROM "#{table_name}" WHERE logical_id = $1""", [logical_id]
  plv8.execute """DELETE FROM "#{table_name}"_history WHERE logical_id = $1""", [logical_id]
  resource

destroy.plv8 = 'fhir.destroy(rt text, logical_id text) returns json'
exports.delete = destroy

update = (plv8, resource)->
  table_name = util.table_name(resource.resourceType)
  logical_id = resource.id
  sql = """
    INSERT INTO "#{table_name}_history"
    (logical_id, version_id, published, updated, content)
    SELECT
    logical_id, version_id, published, updated, content
    FROM "#{table_name}" WHERE logical_id = $1 LIMIT 1
  """
  plv8.execute(sql, [logical_id])
  logical_id = resource.id
  version_id = uuid(plv8)

  resource.meta ||= {}
  resource.meta.versionId = version_id

  plv8.execute """
    UPDATE #{table_name}
    SET version_id = $2,
    content = $3
    WHERE logical_id = $1
    """, [logical_id, version_id, JSON.stringify(resource)]

  resource

exports.update = update
