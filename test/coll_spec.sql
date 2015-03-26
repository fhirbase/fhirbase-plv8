-- #import ../src/tests.sql
-- #import ../src/fhirbase_coll.sql

fhirbase_coll._butlast('{1,2,3}'::varchar[]) => '{1,2}'::varchar[]

fhirbase_coll._rest('{1,2,3,4,5}'::varchar[]) => '{2,3,4,5}'::varchar[]

fhirbase_coll._last('{1,2,3,4,5}'::varchar[]) => '5'
