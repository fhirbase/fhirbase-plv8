params = require('../../src/fhir/params')

specs = [
  ['a=1', [{name: 'a', value: ['1'], operator: 'eq'}]]
  ['a=1&b=2&c=3', [{name: 'a', value: ['1'], operator: 'eq'},{name: 'b', value: ['2'], operator: 'eq'},{name: 'c', value: ['3'], operator: 'eq'}]]
  ['a=missing:1', [{name: 'a', value: ['1'], operator: 'ne'}]]
]

# describe "Params", ()->
#   it "simple", ()->
#     for [k,v] in specs
#       expect(params.parse(k)).toEqual(v)
#
# (= (param name) nicola)
# => extract_as_string_array(resource, '['name']',) && ARRAY['nicola']

specs = [
  ['a=1', ['equal', ['param', 'a'], '1']]
  ['a=1,2', ['equal', ['param', 'a'], ['list', '1', '2']]]
  ['a=1&b=2&c=3', ['and', ['equal', ['param', 'a'], '1'], ['equal', ['param','b'], '2']]]
  ['a=missing:1', ['is-null', 'a', '1']]
  ['subject:Patient.name=ups', ['equal', ['chain', 'subject',
                                                   ['param','Patient','name']],
                                         'ups']]]
