-- #import ../src/tests.sql
-- #import ../src/path.sql

path._is_descedant('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[]) =>  true

path._is_descedant('{1,2,3,5}'::varchar[], '{1,2,3,4,5}'::varchar[]) => false

path._subpath('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[]) =>  '{4,5}'::varchar[]
