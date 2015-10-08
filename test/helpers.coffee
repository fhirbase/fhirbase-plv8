yaml = require('js-yaml')
fs   = require('fs')
exports.loadYaml = (pth)->
  yaml.safeLoad(fs.readFileSync(pth))
