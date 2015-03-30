INSERT into searchparameter
(
  version_id,
  logical_id,
  resource_type,
  name,
  base,
  xpath,
  path,
  search_type,
  is_primitive,
  type,
  content
)
select
  lower(name) || '-id' as version_id,
  lower(name) || '-id' as logical_id,
  'SearchParameter' as resource_type,
  '_id' as name,
  name as base,
  'f:' || name || '/f:id' as xpath,
  ARRAY[name, 'id']::text[] as path,
  'identifier' as search_type,
  true as is_primitive,
  'id' as type,
  json_build_object(
    'resourceType', 'SearchParameter',
    'id', lower(name || '-id'),
    'name', '_id',
    'url', 'http://hl7.org/fhir/SearchParameter/' || lower(name || '-id'),
    'type', 'identifier',
    'xpath', 'f:' || name || '/f:id',
    'description', 'Search by Logical Id'
  )::jsonb as content
  from structuredefinition
 where kind = 'resource'
 order by name

