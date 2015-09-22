get_in = (acc, e, p)->
  return acc.push(e) if p.length == 0
  next = e[p[0]]
  return unless next
  newpath = p[1..-1]
  if Array.isArray(next)
    get_in(acc, n, newpath) for n in next
  else
    get_in(acc, next, newpath)
  return acc

get_path = (plv8, resource, path)->
  path = path.split('.')
  path.shift()
  get_in([], resource, path)

get_path.plv8 = 'fhir.get_path(resource json, path text) returns json'
exports.get_path = get_path

#console.log get_path({},{a: {b: [{c: "x"},{c: "y"}]}}, 'P.a.b.c')
