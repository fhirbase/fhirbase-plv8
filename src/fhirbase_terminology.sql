-- #import ./fhirbase_crud.sql

jsfn expand(_vs_id text, _filter_ text) RETURNS json
  var p = function(x){ plv8.elog(WARNING, JSON.stringify(x)); }
  var r = plv8.execute("SELECT content::json FROM valueset WHERE logical_id = $1", _vs_id)[0];
  if(!r){ return null; }

  var fltr = _filter_.toLowerCase();

  function smatch(s){
    return s && s.toLowerCase().indexOf(fltr) > -1;
  }

  function match(c){
    return smatch(c.code) || smatch(c.display);
  }

  var vs = r.content;
  var codes = [];

  if(vs.define && vs.define.concept){
    vs.define && vs.define.concept && vs.define.concept.forEach(function(c){
      if(match(c)){
        c.system = vs.define.system;
        codes.push(c);
      }
    });
  }
  if(vs.compose && vs.compose.include){
    vs.compose.include.forEach(function(x){
      x.concept && x.concept.forEach(function(c){
        if(match(c)){
          c.system = x.system;
          codes.push(c);
        }
      });
    });
  }
  vs.expansion = {
    identifier: '???',
    timestamp: '???',
    contains: codes
  }
  return vs;
