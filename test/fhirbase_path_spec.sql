-- #import ../src/tests.sql
-- #import ../src/fhirbase_path.sql

fhirbase_path._is_descedant('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[]) =>  true

fhirbase_path._is_descedant('{1,2,3,5}'::varchar[], '{1,2,3,4,5}'::varchar[]) => false

fhirbase_path._subpath('{1,2,3}'::varchar[], '{1,2,3,4,5}'::varchar[]) =>  '{4,5}'::varchar[]
