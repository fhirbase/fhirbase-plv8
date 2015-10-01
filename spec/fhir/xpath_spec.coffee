xpath = require('../../src/fhir/xpath')

samples = [
  [
    "f:DataElement/f:element/f:mapping/f:extension[@url='http://hl7.org/fhir/StructureDefinition/11179-objectClass'",
    [["element","mapping",["extension",["url","http://hl7.org/fhir/StructureDefinition/11179-objectClass"]]]]
  ]

  [
    "f:Patient/f:identifier[type/coding/@code='SSN']/value",
    [[['identifier', [['type','coding','code'], 'SSN']], 'value']]
  ]
]

describe "CRUD", ()->
  it "simple", ()->
    for [k,v] in samples
      expect(xpath.parse(k)).toEqual(v)


yaml = require('js-yaml')
fs   = require('fs')

pt = yaml.safeLoad(fs.readFileSync("#{__dirname}/pt.yaml", 'utf8'))

xpath.get_in(pt,[['identifier', 'value']]) # ['12345', '777']

spec =
  [
    [[['name', 'given']], [ 'Peter', 'James', 'Jim' ]]
    [[[['name', ['use', 'usual']], 'given']], [ 'Jim' ]]
    [[[['name', ['use', 'official']], 'given']], [ 'Peter', 'James' ]]
    [[['identifier', 'value']], ['12345', '777']]
    [[[['name', ['use', 'official']], 'given']], [ 'Peter', 'James' ]]

    [[[['identifier', [['type','coding','code'], 'SSN']], 'value']], ['777']]
    [[[['identifier', [['type','coding','code'], 'MR']], 'value']], ['12345']]
  ]

describe "CRUD", ()->
  it "simple", ()->
    for  [k,v] in spec
      expect(xpath.get_in(pt, k)).toEqual(v)
