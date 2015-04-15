-- #import ../src/tests.sql
-- #import ../src/fhir.sql

SET search_path TO fhir, vars, public;

BEGIN;

SELECT fhir.generate_tables('{Order}');

setv('created',
  fhir.update( '{"resourceType":"Order", "id":"myid"}'::jsonb)
);

fhir.read('Order', 'myid') => getv('created')
fhir.read('Order', 'Order/myid') => getv('created')

expect 'id is myid'
  getv('created')->>'id'
=> 'myid'

expect 'order in table'
  SELECT count(*) FROM "order"
  WHERE logical_id = 'myid'
=> 1::bigint

expect 'meta info'
  jsonb_typeof(getv('created')->'meta')
=> 'object'

expect 'meta info'
  jsonb_typeof(getv('created')#>'{meta,versionId}')
=> 'string'

expect 'meta info'
  jsonb_typeof(getv('created')#>'{meta,lastUpdated}')
=> 'string'

setv('without-id',
  fhir.create( '{"resourceType":"Order", "name":{"text":"Goga"}}'::jsonb)
);

expect 'id was set'
  SELECT (getv('without-id')->>'id') IS NOT NULL
=> true


expect 'meta respected in create'
  fhir.create( '{"resourceType":"Order", "meta":{"tags":[1]}}'::jsonb)#>'{meta,tags}'
=> '[1]'::jsonb

expect 'order created'
  SELECT count(*) FROM "order"
  WHERE logical_id = getv('without-id')->>'id'
=> 1::bigint


fhir.update('{"resourceType":"Order", "id":"myid", "meta":{"versionId":"wrong"}}'::jsonb)#>>'{issue,0,code,coding,1,code}' => '422'

expect 'updated'
  SELECT count(*) FROM "order_history"
  WHERE logical_id = 'myid'
=> 0::bigint

setv('updated',
  fhir.update(
    fhirbase_json.assoc(getv('created'),'name','{"text":"Updated name"}')
  )
);

expect 'updated'
  SELECT count(*) FROM "order_history"
  WHERE logical_id = 'myid'
=> 1::bigint

fhir.read('Order', 'myid')#>>'{name,text}' => 'Updated name'

fhir.vread('Order', getv('created')#>>'{meta,versionId}') => getv('created')

expect "latest"
  fhir.is_latest( 'Order', 'myid',
    getv('updated')#>>'{meta,versionId}')
=> true

expect "not latest"
  fhir.is_latest( 'Order', 'myid',
    getv('created')#>>'{meta,versionId}')
=> false

fhir.history( 'Order', 'myid', '')#>'{entry,0,resource}' => getv('updated')
fhir.history( 'Order', 'myid', '')#>'{entry,1,resource}' => getv('created')

expect '2 items for resource history'
  jsonb_array_length(
    fhir.history( 'Order', 'myid', '')->'entry'
  )
=> 2

expect '4 items for resource type history'
  jsonb_array_length(
    fhir.history('Order', '')->'entry'
  )
=> 4

expect 'more then 4 items for all history'
  jsonb_array_length(
    fhir.history('')->'entry'
  ) > 4
=> true

-- SEARCH

expect 'not empty search'
  jsonb_array_length(
    fhir.search( 'Order', '')->'entry'
  )
=> 3

-- DELETE

fhir.is_exists( 'Order', 'myid') => true
fhir.is_deleted( 'Order', 'myid') => false

setv('deleted',
  fhir.delete( 'Order', 'myid')
);

fhir.delete( 'Order', 'myid')#>>'{issue,0,code,coding,1,code}' => '410'
fhir.delete( 'Order', 'nonexisting')#>>'{issue,0,code,coding,1,code}' => '404'

fhir.read('Order', 'myid')#>>'{issue,0,code,coding,1,code}' => '410'

fhir.is_exists( 'Order', 'myid') => false
fhir.is_deleted( 'Order', 'myid') => true


getv('deleted')#>>'{meta,versionId}' => getv('updated')#>>'{meta,versionId}'

ROLLBACK;
