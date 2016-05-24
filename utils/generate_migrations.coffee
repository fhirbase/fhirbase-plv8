fs = require('fs')
plv8 = {} # HACK to make it do not require connection require('../plpl/src/plv8')
sql = require('../src/honey')
schema = require('../src/core/schema')

output = (x)->
  if Array.isArray(x)
    console.log(x[0], ";")
  else
    console.log(x, ";")

for ex in [":pgcrypto", ":plv8", ":pg_trgm"]
  output sql({create: "extension", name: ex, safe: true})

TZ = "TIMESTAMP WITH TIME ZONE"

base_columns  =[
  [':id',':text']
  [':version_id',':text']
  [':resource_type',':text']
  [':resource',':jsonb']
]

output sql(
  create: ":table"
  name: ':resource'
  columns: base_columns.concat([
    [':created_at', ':timestamp with time zone']
    [':updated_at', ':timestamp with time zone']
  ])
)


output sql(
  create: ":table"
  name: ':resource_history'
  columns: base_columns.concat([
    [':valid_from', ':timestamp with time zone']
    [':valid_to', ':timestamp with time zone']
  ])
)

output  schema.fhir_create_storage_sql(plv8, resourceType: 'StructureDefinition')
output  schema.fhir_create_storage_sql(plv8, resourceType: 'SearchParameter')
output  schema.fhir_create_storage_sql(plv8, resourceType: 'OperationDefinition')
output  schema.fhir_create_storage_sql(plv8, resourceType: 'ValueSet')
output  schema.fhir_create_storage_sql(plv8, resourceType: 'ConceptMap')
output  schema.fhir_create_storage_sql(plv8, resourceType: 'NamingSystem')
output  schema.fhir_create_storage_sql(plv8, resourceType: 'CodeSystem')

bundles = [
  require('../fhir/search-parameters.json')
  require('../fhir/profiles-types.json')
  require('../fhir/profiles-resources.json')
  require('../fhir/valuesets.json')
  require('../fhir/v2-tables.json')
  require('../fhir/v3-codesystems.json')
]

VERSION = "1"

output "CREATE TEMP TABLE metadata_with_dups (resource jsonb);"
output "CREATE TEMP TABLE metadata (resource jsonb);"

output """
-- Create a function that always returns the first non-NULL item
CREATE OR REPLACE FUNCTION first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
  SELECT $1;
$$;

-- And then wrap an aggregate around it
CREATE AGGREGATE FIRST (
  sfunc    = first_agg,
  basetype = anyelement,
  stype    = anyelement
);
"""

is_first = true

console.log "INSERT INTO  metadata_with_dups (resource) VALUES "
#.replace(/\{"/g, '{ "').replace(/\.(participation|role)\{/g, '$1[')
for bundle in bundles
  for entry in bundle.entry when entry.resource
    resource = entry.resource
    comma = if is_first then "" else ","
    console.log comma, "( $JSON$ #{JSON.stringify(resource)} $JSON$ )"
    is_first = false

console.log ";"

console.log """
  INSERT INTO metadata (resource)
  (
    SELECT first(resource)
    FROM metadata_with_dups
    GROUP BY resource->>'id', resource->>'resourceType'
  );
"""

for tp in ['StructureDefinition', 'SearchParameter', 'OperationDefinition', 'ValueSet', 'ConceptMap', 'NamingSystem', 'CodeSystem']
  console.log """
    INSERT INTO #{tp.toLowerCase()} (id, version_id, resource)
    SELECT m.resource->>'id', m.resource->>'id' || '-#{VERSION}' , resource
    FROM metadata m
    WHERE m.resource->>'resourceType' = '#{tp}'
  ;

  """
  console.log """
    INSERT INTO #{tp.toLowerCase()}_history (id, version_id, resource, valid_from, valid_to)
    SELECT m.resource->>'id', m.resource->>'id' || '-#{VERSION}' , resource, CURRENT_TIMESTAMP, 'infinity'
    FROM metadata m
    WHERE m.resource->>'resourceType' = '#{tp}'
  ;
  """
