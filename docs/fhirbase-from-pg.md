## How fhirbase works?


```bash
wget http://hl7-fhir.github.io/examples-json.zip
unzip examples-json.zip
psql
```

```sql
create database fhir_tutor;
\c fhir_tutor
create table resources (id serial primary key, resource jsonb);
\dt

```


```sh
for res in *json; do; psql fhir_tutor -c "insert into resources (resource) values (\$JSON\$$(cat $res)\$JSON\$)"; done;
```


```sql
select count(*) from resources;

 count
-------
  1906
(1 row)



select count(*), resource->>'resourceType'
from resources
group by resource->>'resourceType'
order by count(*) desc;

 count |          ?column?
-------+----------------------------
   977 | StructureDefinition
   188 | Questionnaire
    65 | ConceptMap
    50 | Observation
    46 | Medication
    36 | Claim
    34 | MedicationOrder
    34 | OperationDefinition
    28 | Condition
    26 | NutritionOrder
    24 | SearchParameter
    21 | DiagnosticReport
    20 | Encounter
    20 | CarePlan
    18 | AuditEvent
    18 | Bundle
    16 | DetectedIssue
    14 | Device
.....
(69 rows)



select
  resource#>>'{code,text}' as code
  ,resource
from resources
where resource->>'resourceType' = 'Condition'


select
  resource#>>'{code,coding,0,display}' as code
  ,resource#>>'{patient, reference}' as pt
  ,resource
from resources
where
  resource->>'resourceType' = 'Condition'
  and resource#>>'{patient, reference}'  = 'Patient/f001'


-- find all conditions with 368009
select
  resource#>>'{code,coding,0,display}' as code
  ,resource#>>'{code,coding,0,system}' as system
  ,resource#>>'{code,coding,0,code}' as code
  ,resource#>>'{patient, reference}' as pt
  ,resource
from resources
where
  resource->>'resourceType' = 'Condition'
  and
  (
    (
      (resource#>>'{code,coding,0,system}')
      || '|' ||
      (resource#>>'{code,coding,0,code}')
    )
    = 'http://snomed.info/sct|368009'
    or
    (
      (resource#>>'{code,coding,1,system}')
      || '|' ||
      (resource#>>'{code,coding,1,code}')
    )
    = 'http://snomed.info/sct|368009'
  )



/* create extension plv8; */
drop  function extract_text_array(resource json, path json);

create or replace function extract_text_array(resource json, path json)
RETURNS text[] AS $$

function get(acc, obj, path){
  if(path.length == 0 && obj){ acc.push(obj); return acc; }
  var item =path[0];
  var next = obj[item];
  if(next){
    var new_path = path.slice(1);
    if(Array.isArray(next)){
      return next.reduce(function(acc, x){
        return get(acc, x, new_path);
      }, acc)
    }else{
      return get(acc, next, new_path);
    }
  }else{
    return acc;
  }
};

return get([],resource, path);
$$ LANGUAGE plv8 IMMUTABLE STRICT;
select extract_text_array('{"a": [{"b": [{"c": 4}]}, {"b": [{"c": 4}]}]}'::json, '["a","b", "c"]'::json)

select
  resource#>>'{code,coding,0,display}' as code
  ,extract_text_array(resource::json, '["code","coding", "code"]'::json)
  ,resource
from resources
where
  resource->>'resourceType' = 'Condition'
  and extract_text_array(resource::json, '["code","coding", "code"]'::json) && ARRAY['368009']::text[];



create or replace function extract_from_codable_concept_to_text_array(resource json, path json)
RETURNS text[] AS $$

function get(acc, obj, path){
  if(path.length == 0 && obj){ acc.push(obj); return acc; }
  var item =path[0];
  var next = obj[item];
  if(next){
    var new_path = path.slice(1);
    if(Array.isArray(next)){
      return next.reduce(function(acc, x){
        return get(acc, x, new_path);
      }, acc)
    }else{
      return get(acc, next, new_path);
    }
  }else{
    return acc;
  }
};

var concepts = get([], resource, path);

plv8.elog(NOTICE, JSON.stringify(concepts));

var res = [];

(concepts || []).forEach(function(concept){
  (concept.coding || []).forEach(function(coding){
    res.push(coding.code);
    res.push(coding.system + "|" + coding.code);
  })
})

return res;
$$ LANGUAGE plv8 IMMUTABLE STRICT;

select
  extract_from_codable_concept_to_text_array(resource::json, '["code"]'::json)
  ,resource
from resources
where
  resource->>'resourceType' = 'Condition'
  and extract_from_codable_concept_to_text_array(resource::json, '["code"]'::json) && ARRAY['http://snomed.info/sct|422504002']::text[]
```

