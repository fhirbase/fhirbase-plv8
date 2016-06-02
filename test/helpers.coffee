yaml = require('js-yaml')
fs   = require('fs')
lang = require('../src/lang')
assert = require('assert')

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

match_recur = (obj, sample, path)->
  if lang.isArray(sample)
    for v,i in sample
      next = obj[i]
      new_path = path.concat(i)
      if not next?
        assert(false, "No object on #{new_path.join('.')}, but #{JSON.stringify(obj)}")
      match_recur(next, v, new_path)
  else if lang.isObject(sample)
    for k,v of sample
      next = obj[k]
      new_path = path.concat(k)
      if not next?
        assert(false, "No object on #{new_path.join('.')}, but #{JSON.stringify(obj)}")
      match_recur(next, v, new_path) 
  else
    assert.equal(obj, sample, "Path #{path.join('.')}")


exports.match = (obj, sample)->
  match_recur(obj, sample, [])
