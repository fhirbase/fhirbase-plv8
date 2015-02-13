-- #import ../src/tests.sql
-- #import ../src/vars.sql

delv('ups');
setv('ups','{"a":1}'::jsonb);

vars.getv('ups') => '{"a":1}'::jsonb

delv('ups');

vars.getv('ups') => NULL::jsonb

