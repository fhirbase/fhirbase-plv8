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
  DO $JS$
     var log = function(x){plv8.elog(NOTICE, x)}

     function expand_concept(acc, props, parent, concept){
          acc.push({
              valueset_id: props.valueset_id,
              system: props.system,
              parent_code: parent.code,
              code: concept.code,
              display: concept.display,
              definition: concept.definition,
              abstract: concept.abstract,
              designation: JSON.stringify(concept.designation),
              extension: JSON.stringify(concept.estension)
          })

          if(concept.concept){
              var cnt = concept.concept.length
              for(var i = 0; i < cnt; i++){
                  expand_concept(acc, props, concept, concept.concept[i])
              }
          }
          return acc
     };

     function expand(vs){
          var acc = [];
          var codeSystem = vs.codeSystem;
          var props = { valueset_id: vs.id };
          if(codeSystem && codeSystem.concept) {
              props.system = codeSystem.system;
              var cnt = codeSystem.concept.length
              for(var i = 0; i < cnt; i++){
                  expand_concept(acc, props, {}, codeSystem.concept[i]);
              }
          }
          var includes = vs.compose && vs.compose.include
          if(includes){
              var cnt = includes.length
              for(var i = 0; i < cnt; i++){
                  var include = includes[i]
                  props.system = include.system;
                  for(var j = 0; j < (include.concept && include.concept.length) || 0; j++){
                      expand_concept(acc, props, {}, include.concept[j]);
                  }
                  var syst = plv8.execute("SELECT * FROM codesystem WHERE resource->>'url' = $1 LIMIT 1", include.system);
                  var syst_res = syst && syst[0] && syst[0].resource && parse(syst[0].resource);
                  /* if(syst_res && syst_res.concept.length > 0){ */
                  /*   log("+ " + include.system + '  (' + syst_res.concept.length + ')'); */
                  /* } */
                  for(var j = 0; j < (syst_res && syst_res.concept.length) || 0; j++){
                    expand_concept(acc, props, {}, syst_res.concept[j]);
                  }
              }
          }
          return acc;
     }

     function parse(x){
       if(typeof x === 'string'){
         return JSON.parse(x);
       }else{
         return x;
       }
     }

     var plan = plv8.prepare( 'SELECT * FROM valueset');
     var cursor = plan.cursor();
     var row = null;
     while (row = cursor.fetch()) {
       var res = parse(row.resource)
       var items = expand(res);
       if(items.length > 0){
          log('expand valueset: ' + res.id + ' (' + items.length + ')')
          plv8.execute(
              "INSERT INTO _valueset_expansion" +
              "(valueset_id, system, parent_code, code, display, abstract, definition, designation, extension) " +
              "SELECT x->>'valueset_id', x->>'system', x->>'parent_code', x->>'code', x->>'display', (x->>'abstract')::boolean, x->>'definition', (x->'designation')::jsonb, (x->'extension')::jsonb " +
              "FROM json_array_elements($1::json) x"
          , JSON.stringify(items))
       }
     }
     cursor.close();
     plan.free();

  $JS$ LANGUAGE plv8;
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
