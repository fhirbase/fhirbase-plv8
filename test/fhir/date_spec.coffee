date = require('../../src/fhir/date')
assert = require('assert')

specs = [
  ['2010', '[2010-01-01,2011-01-01)']
  ['2010-03', '[2010-03-01,2010-04-01)']
  ['2010-12', '[2010-12-01,2011-01-01)']
  ['2010-03-05', '[2010-03-05,2010-03-05T23:59:59.99999]']
  ['2010-03-05 10', '[2010-03-05T10:00,2010-03-05T10:59:59.99999)']
  ['2010-03-05 23', '[2010-03-05T10:00,2010-03-05T23:59:59.99999]']
]
describe "CRUD", ()->
  it "simple", ()->
    for [k,v] in specs
      console.log(k, 'should',v)

counter = 1
start = new Date()
for x in [0..1000000]
  # [1,2,3,4,5].reduce(((acc, x)-> acc + x),0)
  acc = 0
  for x in [1,2,3,4,5]
    acc + x
  counter += 1
end = new Date()

console.log(counter, end - start, 'ms')
