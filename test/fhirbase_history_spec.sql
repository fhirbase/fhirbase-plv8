-- #import ../src/tests.sql
-- #import ../src/fhirbase_crud.sql
-- #import ../src/fhirbase_history.sql
SET search_path TO vars, public;

BEGIN;

SELECT fhirbase_generate.generate_tables('{Patient}');

setv('pt-1',
  fhirbase_crud.update('{}'::jsonb, '{"resourceType":"Patient", "id":"myid"}'::jsonb)
);

setv('second-pt',
  fhirbase_crud.create('{}'::jsonb, '{"resourceType":"Patient", "name":{"text":"Goga"}}'::jsonb)
);


setv('ptu-1',
  fhirbase_crud.update('{}'::jsonb,
    fhirbase_json.assoc(getv('pt-1'),'name','{"text":"Updated name"}')
  )
);

expect
  jsonb_array_length(
    fhirbase_history.history('{}'::jsonb, 'Patient', 'myid')#>'{entry}'
  )
=> 2

expect
  fhirbase_history.history('{}'::jsonb, 'Patient', 'myid')#>'{entry,0,resource}'
=> getv('ptu-1')

expect
  fhirbase_history.history('{}'::jsonb, 'Patient', 'myid')#>'{entry,1,resource}'
=> getv('pt-1')

expect '3 items for resource type history'
  jsonb_array_length(
    fhirbase_history.history('{}'::jsonb, 'Patient')->'entry'
  )
=> 3

expect 'more then 4 items for all history'
  jsonb_array_length(
    fhirbase_history.history('{}'::jsonb)->'entry'
  ) > 4
=> true

ROLLBACK;
