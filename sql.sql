--db:test
--{{{
create extension if not exists plv8;

DROP FUNCTION plv8_init();
CREATE FUNCTION plv8_init() RETURNS text AS $$
 plv8.elog(NOTICE, 'init');
 var log = function(x){ plv8.elog(NOTICE, 'log:' + x) };
 this.console = {log: log}
 this.require  = function(x){ log('require:' +x )};
$$ LANGUAGE plv8 IMMUTABLE STRICT;

DROP FUNCTION plv8_test();
CREATE FUNCTION plv8_test() RETURNS text AS $$
 require('str')
 console.log('hoha');
$$ LANGUAGE plv8 IMMUTABLE STRICT;


--}}}
--{{{
SET plv8.start_proc = 'plv8_init';
SELECT plv8_test();
SELECT plv8_test();
--}}}
