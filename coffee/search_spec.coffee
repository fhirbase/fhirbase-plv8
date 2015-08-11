plv8 = require('./plv8')
p = (x)-> console.log(JSON.stringify(x))
subject = require('./search.coffee')

CASES =
  'param=num':  [{key: 'param', value: ['num'], op: 'eq'}]
  'param=num&param=num2': [{key: 'param', value: ['num'], op: 'eq'}, {key: 'param', value: ['num2'], op: 'eq'}]
  'param=<num': [{key: 'param', value: ['num'], op: 'lt'}]
  'param=<=num':  [{key: 'param', value: ['num'], op: 'le'}]
  'param=<%3Dnum':  [{key: 'param', value: ['num'], op: 'le'}]
  'param=>num': [{key: 'param', value: ['num'], op: 'gt'}]
  'param=>=num': [{key: 'param', value: ['num'], op: 'ge'}]
  'param=>%3Dnum':  [{key: 'param', value: ['num'], op: 'ge'}]
  'param=!=num': [{key: 'param', value: ['num'], op: 'ne'}]
  'param:missing=true': [{key: 'param', value: ['true'], op: 'missing'}]
  'param:missing=false': [{key: 'param', value: ['false'], op: 'missing'}]
  'param:exact=num': [{key: 'param', value: ['num'], op: 'exact'}]
  'param=~ups': [{key: 'param', value: ['ups'], op: 'ap'}]
  'patient:Patient.name=ups': [{chain: [{from: 'Encounter', on: 'patient',to: 'Patient'}], key: 'name', value: ['ups'], op: 'eq'}]
  'patient:Patient.organization:Organization.name=ups': [{chain: [{from: 'Encounter', on: 'patient',to: 'Patient'}, {from: 'Patient', on: 'organization', to: 'Organization'}], key: 'name', value: ['ups'], op: 'eq'}]

diff= require('jsondiffpatch')

comment = ->
 describe "param parser", ->
  for k,v of CASES
    it 'ups', ->
      res = subject.parse_params('Encounter', k)
      df = diff.diff(res, v)
      console.log JSON.stringify(df) if df
      expect(res).toEqual(v)

expands  = [
 ['Encounter', [{key: 'patient'}],
   [{"key":"patient","path":"[\"Encounter\",\"patient\"]","base":"Encounter","search_type":"reference","type":null,"is_primitive":null}]]
 ['Patient', [{key: 'given'}],
   [{"key":"given","path":"[\"Patient\",\"name\",\"given\"]","base":"Patient","search_type":"string","type":"string","is_primitive":true}]]
 ['Encounter', [{chain: [{from: 'Encounter', on: 'patient',to: 'Patient'}, {from: 'Patient', on: 'organization', to: 'Organization'}], key: 'name', value: ['ups'], op: 'eq'}],
   [{"chain":[{"from":"Encounter","on":"patient","to":"Patient","path":"[\"Encounter\",\"patient\"]","base":"Encounter","search_type":"reference","type":null,"is_primitive":null},{"from":"Patient","on":"organization","to":"Organization","path":"[\"Patient\",\"managingOrganization\"]","base":"Patient","search_type":"reference","type":null,"is_primitive":null}],"key":"name","value":["ups"],"op":"eq","path":"[\"Organization\",\"name\"]","base":"Organization","search_type":"string","type":"string","is_primitive":true}]]
]

comment = ->
 describe "param parser", ->
  for [res_type,prm, exp] in expands
    it 'res_type', ->
      result = subject.expand_params(plv8,res_type, prm)
      df = diff.diff(result, exp)
      console.log df if df
      expect(result).toEqual(exp)

p subject.search(plv8, 'Encounter', 'patient:Patient.organization:Organization.name=ups&type=x')
