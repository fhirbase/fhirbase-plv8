yaml = require('js-yaml')
fs   = require('fs')

exports.loadJson = (pth)->
  JSON.parse(fs.readFileSync(pth, "utf8"))

exports.loadYaml = (pth)->
  yaml.safeLoad(fs.readFileSync(pth, "utf8"))

edn = require("jsedn")

to_js = (obj)->
  if obj.constructor == edn.Map
    res = {}
    for k,idx in obj.keys
      res[k.name.replace(/^:/,'')] = to_js(obj.vals[idx])
    res
  else if obj.constructor == edn.Keyword
    obj.name
  else if obj.constructor == edn.Vector
    obj.val.map(to_js)
  else if obj.constructor == edn.Set
    obj.val.map(to_js)
  else if obj.constructor == edn.List
    ["$#{obj.val[0].name}"].concat(obj.val[1..].map(to_js))
  else if obj.constructor == edn.Symbol
    obj.name
  else
    obj

exports.loadEdn = (pth)->
  str = fs.readFileSync(pth, "utf8")
  to_js(edn.parse(str))
