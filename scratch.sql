--db:fb2
--{{{
CREATE OR REPLACE FUNCTION plv8_init() RETURNS text AS $$
  var deps = {
    './utils': {
      init: function(){
         return function(){ return 'hoho'}
      },
      cached: null
    }
  };
  this.require = function(dep){
    var mod = deps[dep]
    if(!mod.cached){ mod.cached = mod.init() }
    return mod.cached
  }
  this.console = {
    log: function(x){ plv8.elog(NOTICE, x); }
  };
  return 'ok'
$$ LANGUAGE plv8 IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION plv8_test() RETURNS text AS $$
  var u = require('./utils');
  return console.log(u());
$$ LANGUAGE plv8 IMMUTABLE STRICT;
--}}}

--{{{

SET plv8.start_proc = 'plv8_init';
SELECT plv8_test();

DO $$
  var u = require('./utils');
  return u();

$$ LANGUAGE plv8;
--}}}
