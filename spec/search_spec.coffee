plv8 = require('../lib/plv8')
search = require('../src/search')

describe "Search", ()->
  it "search", ()->
    sql = search.search_sql(plv8, 'StructureDefinition', 'name', 'enc')
    expect(sql).toMatch(/select/i)
    res = search.search(plv8, 'StructureDefinition', 'name', 'enco')
    expect(res.length).toEqual(1)

  it "in db", ()->
    np = require('../lib/node2pl')
    np.scan('../src/search')
    res = plv8.execute(
      'SELECT fhir.search($1,$2,$3) as search',
      ['StructureDefinition', 'name', 'enco'])[0]['search']
    res = JSON.parse(res)
    expect(res.length).toEqual(1)
