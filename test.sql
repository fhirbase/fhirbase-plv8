-- Compile src/fhir/crud.coffee
CREATE OR REPLACE FUNCTION plv8_init() RETURNS text AS $$
  var _modules = {};
  var _current_file = null;
  var _current_dir = null;

  // modules start
  _modules["/root/fhirbase-plv8/src/fhir/crud"] = {
  init:  function(){
    var exports = {};
    _current_file = "crud";
    _current_dir = "/root/fhirbase-plv8/src/fhir";
    var module = {exports: exports};
    (function() {
  var utils;

  utils = require('./utils');

  exports.plv8_schema = 'fhir';

  exports.create = function(plv8, resource) {
    console.log(utils.table_name("Patient"));
    return console.log('create');
  };

  exports.create.plv8_signature = ['jsonb', 'jsonb'];

  exports.update = function(plv8, resource) {
    return console.log('update');
  };

  exports.update.plv8_signature = ['jsonb', 'jsonb'];

  exports["delete"] = function(plv8, resource_type, id) {
    return console.log('delete');
  };

  exports["delete"].plv8_signature = ['text', 'text', 'jsonb'];

  exports.read = function(plv8, resource_type, id) {
    return console.log('read');
  };

  exports["delete"].plv8_signature = ['text', 'text', 'jsonb'];

  exports.vread = function(plv8, resource_type, id, version_id) {
    return console.log('vread');
  };

  exports["delete"].plv8_signature = ['text', 'text', 'text', 'jsonb'];

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/fhir/utils"] = {
  init:  function(){
    var exports = {};
    _current_file = "utils";
    _current_dir = "/root/fhirbase-plv8/src/fhir";
    var module = {exports: exports};
    (function() {
  exports.table_name = function(resource_name) {
    return resource_name.toLowerCase();
  };

}).call(this);

    return module.exports;
  }
}
  // modules stop

  this.require = function(dep){
    var abs_path = dep.replace(/\.coffee$/, '');
    if(dep.match(/\.\//)){
      abs_path = _current_dir + '/' + dep.replace('./','');
    }
    // todo resolve paths
    var mod = _modules[abs_path]
    if(!mod){ throw new Error("No module " + abs_path)}
    if(!mod.cached){ mod.cached = mod.init() }
    return mod.cached
  }
  this.modules = function(){
    var res = []
    for(var k in _modules){ res.push(k) }
    return res;
  }
  this.console = {
    log: function(x){ plv8.elog(NOTICE, x); }
  };
  return 'done'
$$ LANGUAGE plv8 IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION
fhir.create(resource jsonb)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/fhir/crud.coffee")
  mod.create(plv8, resource)
$$ LANGUAGE plv8;
CREATE OR REPLACE FUNCTION
fhir.update(resource jsonb)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/fhir/crud.coffee")
  mod.update(plv8, resource)
$$ LANGUAGE plv8;
CREATE OR REPLACE FUNCTION
fhir.delete(resource_type text, id text)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/fhir/crud.coffee")
  mod.delete(plv8, resource_type, id)
$$ LANGUAGE plv8;
