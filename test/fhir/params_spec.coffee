params = require('../../src/fhir/params')
test = require('../helpers')
assert = require('assert')

specs = test.loadYaml(__dirname + '/params_spec.yaml')

# ['_filter=name eq http://loinc.org|1234-5 and subject.name co "peter"',[{name: '', value: []}]]

describe "Params", ()->
 it "params", ()->
   for k,v of specs.params
     assert.deepEqual(params.parse(k).params, v)

 it "other", ()->
   for k,v of specs.specials
     res = params.parse(k)
     delete res.params
     assert.deepEqual(res, v)
