json = require('./json')
idx_humanname_as_string = (plv8, resource, path)->
  names = json.get_path(plv8,resource, path)
  res = []
  parts = ['family','given','suffix', 'prefix']
  for name in names
    parts.push(name.text)  if name.text
    for p in parts
      res.push(name[p].join(' ')) if name[p]

idx_humanname_as_string.plv8 = 'idx_humanname_as_string(resource json, path text) returns text'
exports.idx_humanname_as_string = idx_humanname_as_string

idx_string_as_string = (plv8, resource, path)->
  res = json.get_path(plv8,resource, path)
  res && res.join(" ")

idx_string_as_string.plv8 = 'idx_string_as_string(resource json, path text) returns text'
exports.idx_string_as_string = idx_string_as_string
