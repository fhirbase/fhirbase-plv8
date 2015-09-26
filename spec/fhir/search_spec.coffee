plv8 = require('../../plpl/src/plv8')
crud = require('../../src/fhir/crud')
schema = require('../../src/fhir/schema')
search = require('../../src/fhir/search')

yaml = require('js-yaml')
fs   = require('fs')

specs = yaml.safeLoad(fs.readFileSync("#{__dirname}/search_spec.yml", 'utf8'))


describe "CRUD", ()->
  beforeEach ()->
    schema.drop_table(plv8, 'Something')
    schema.create_table(plv8, 'Something')

  it "simple", ()->
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
      expect(res.total).toEqual(sp.total)
