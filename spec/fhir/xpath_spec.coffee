xpath = require('../../src/fhir/xpath')

samples = [
  [
    "f:DataElement/f:element/f:mapping/f:extension[@url='http://hl7.org/fhir/StructureDefinition/11179-objectClass'",
    [["element","mapping",["extension",["@url","http://hl7.org/fhir/StructureDefinition/11179-objectClass"]]]]
  ]
]

describe "CRUD", ()->
  it "simple", ()->
    for [k,v] in samples
      expect(xpath.parse(k)).toEqual(v)


