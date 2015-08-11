jsfn search(resource_type text, query text) RETURNS text
  var parts = query.split("&").map(function(x){
    var comp = x.split('=')
    var key = comp[0]
    var val = comp[1]
  })
  return decodeURI(query)

