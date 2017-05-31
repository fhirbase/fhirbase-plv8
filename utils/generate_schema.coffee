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

console.log "DROP TABLE IF EXISTS _constants;"
console.log "DROP TABLE IF EXISTS _fhirbase_hook;"
console.log "DROP TABLE IF EXISTS _fhirbase_hook_id_seq;"
console.log "DROP TABLE IF EXISTS _valueset_expansion;"
console.log "DROP TABLE IF EXISTS _valueset_expansion_id_seq;"
console.log "DROP TABLE IF EXISTS codesystem;"
console.log "DROP TABLE IF EXISTS codesystem_history;"
console.log "DROP TABLE IF EXISTS conceptmap;"
console.log "DROP TABLE IF EXISTS conceptmap_history;"
console.log "DROP TABLE IF EXISTS dssm;"
console.log "DROP TABLE IF EXISTS namingsystem;"
console.log "DROP TABLE IF EXISTS namingsystem_history;"
console.log "DROP TABLE IF EXISTS operationdefinition;"
console.log "DROP TABLE IF EXISTS operationdefinition_history;"
console.log "DROP TABLE IF EXISTS resource;"
console.log "DROP TABLE IF EXISTS resource_history;"
console.log "DROP TABLE IF EXISTS searchparameter;"
console.log "DROP TABLE IF EXISTS searchparameter_history;"
console.log "DROP TABLE IF EXISTS structuredefinition;"
console.log "DROP TABLE IF EXISTS structuredefinition_history;"
console.log "DROP TABLE IF EXISTS valueset;"
console.log "DROP TABLE IF EXISTS valueset_history;"

TZ = "TIMESTAMP WITH TIME ZONE"

base_columns  =[
  [':id',':text']
  [':version_id',':text']
  [':resource_type',':text']
  [':resource',':jsonb']
]

console.log "DROP TABLE IF EXISTS structuredefinition;"

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

-- Create function to estimate rows of a query. It's used to improve performance of search function.
CREATE OR REPLACE FUNCTION count_estimate(query text) RETURNS INTEGER AS
$func$
DECLARE
    rec   record;
    ROWS  INTEGER;
BEGIN
    FOR rec IN EXECUTE 'EXPLAIN ' || query LOOP
        ROWS := SUBSTRING(rec."QUERY PLAN" FROM ' rows=([[:digit:]]+)');
        EXIT WHEN ROWS IS NOT NULL;
    END LOOP;

    RETURN ROWS;
END
$func$ LANGUAGE plpgsql;
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

console.log """
  alter table valueset add expanded_at timestamp not null default now();
  alter table valueset add expanded_id uuid;
  drop table if exists  _valueset_expansion;
  create table _valueset_expansion  (
      id serial primary key,
      valueset_id text not null,
      parent_code text,
      system text not null,
      abstract boolean,
      definition text,
      designation jsonb,
      extension jsonb,
      code text not null,
      display text
  );
"""

console.log """
  -- just experiment
  drop table if exists _fhirbase_hook;
  create table _fhirbase_hook  (
      id serial primary key,
      function_name text not null,
      system boolean default false,
      phase text not null,
      hook_function_name text not null,
      weight integer
  );
"""

console.log """
  CREATE INDEX idx_valueset_expansion_ilike
  ON _valueset_expansion
  USING GIN (code gin_trgm_ops, display gin_trgm_ops);
"""

console.log """
  CREATE INDEX idx_valueset_valuset_id ON _valueset_expansion (valueset_id);
"""
