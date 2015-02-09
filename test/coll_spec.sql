-- #import ../src/tests.sql
-- #import ../src/coll.sql

coll._butlast('{1,2,3}'::varchar[]) => '{1,2}'::varchar[]

coll._rest('{1,2,3,4,5}'::varchar[]) => '{2,3,4,5}'::varchar[]

coll._last('{1,2,3,4,5}'::varchar[]) => '5'
