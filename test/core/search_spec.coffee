plv8 = require('../../plpl/src/plv8')
crud = require('../../src/core/crud')
schema = require('../../src/core/schema')
search = require('../../src/core/search')
assert = require('assert')

yaml = require('js-yaml')
fs   = require('fs')

specs = yaml.safeLoad(fs.readFileSync("#{__dirname}/search_spec.yml", 'utf8'))

describe "CORE: search", ()->
  beforeEach ()->
    schema.drop_storage(plv8, 'Something')
    schema.create_storage(plv8, 'Something')

  it "base search", ()->
    sample =
      resourceType: 'Something'
      id: 'sm-1'
      name: 'something'
      contact: [{address: 'Mars'}]

    sample2 =
      resourceType: 'Something'
      name: 'nothing'
      contact: [{address: 'Earth'}]

    created = crud.create(plv8, sample)
    created2 = crud.create(plv8, sample2)

    for sp in specs
      res = search.search(plv8, sp.query)
      if res.total.toString() != sp.total.toString()
        throw new Error()
      assert.equal(res.total, sp.total)
