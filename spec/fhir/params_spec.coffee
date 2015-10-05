params = require('../../src/fhir/params')
assert = require "assert"

specs = [
  ['a=1', ['and', ['or', {name: 'a', value: '1'}]]]
  ['a=a%20a', ['and', ['or', {name: 'a', value: 'a a'}]]]
  ['a=1&b=2&c=3', ['and', ['or', {name: 'a', value: '1'}],
                          ['or', {name: 'b', value: '2'}],
                          ['or', {name: 'c', value: '3'}]]]
  ['a=1,2', ['and', ['or', {name: 'a', value: '1'},
                           {name: 'a', value: '2'}]]]

  ['a:missing=true', ['and', ['or', {name: 'a', value: 'true', modifier: 'missing'}]]]
  ['name:text=ivan', ['and', ['or', {name: 'name', value: 'ivan', modifier: 'text'}]]]
  ['age=lt10', ['and', ['or', {name: 'age', value: '10', prefix: 'lt'}]]]
  ['age=lt20,gt10,eq30&name=ivan', ['and', ['or', {name: 'age', value: '20', prefix: 'lt'},
                                                  #{name: 'age', value: '10', prefix: 'gt'},
                                                  #{name: 'age', value: '30', prefix: 'eq'}],
                                           #['or', {name: 'name', value: 'ivan'}]]]

  # ['name=ap10', [{name: 'name', value: '10', prefix: 'ap'}]]
  # ['type=loinc|444', [{name: 'type', value: [['loinc', '444']]}]]
  # ['multi=a$b', [{name: 'multi', value: [['a', 'b']]}]]
  # ['_limit=10', [{name: '_limit', value: ['10']}]]
  # ['subject:Patient.name=ivan', [{chain: [['subject', 'Patient']], name: 'name', value: ['ivan']}]]
  # ['subject:Patient.name:exact=ivan', [{chain: [['subject', 'Patient']], name: 'name', value: ['ivan'], modifier: 'exact'}]]
  # ['subject:Patient.age=lt10', [{chain: [['subject', 'Patient']], name: 'age', value: ['10'], prefix: 'lt'}]]
  # ['subject:Patient.age=lt10&organization:Organization.id=777', [
  #   {chain: [['subject', 'Patient']], name: 'age', value: ['10'], prefix: 'lt'}
  #   {chain: [['organization', 'Organization']], name: 'id', value: ['777']}]]

  # # Numerics
  # ['parameter=100', [{name: 'parameter', value: ['100']}]]
  # ['parameter=100.00', [{name: 'parameter', value: ['100.00']}]]
  # ['parameter=lt100', [{name: 'parameter', value: ['100'], prefix: 'lt'}]]
  # ['parameter=le100', [{name: 'parameter', value: ['100'], prefix: 'le'}]]
  # ['parameter=gt100', [{name: 'parameter', value: ['100'], prefix: 'gt'}]]
  # ['parameter=ge100', [{name: 'parameter', value: ['100'], prefix: 'ge'}]]
  # ['parameter=ne100', [{name: 'parameter', value: ['100'], prefix: 'ne'}]]

  # # dates
  # ['parameter=eq2013-01-14', [{name: 'parameter', value: ['2013-01-14'], prefix: 'eq'}]]
  # ['parameter=ne2013-01-14', [{name: 'parameter', value: ['2013-01-14'], prefix: 'ne'}]]
  # ['parameter=lt2013-01-14T10:00', [{name: 'parameter', value: ['2013-01-14T10:00'], prefix: 'lt'}]]
  # ['parameter=gt2013-01-14T10:00', [{name: 'parameter', value: ['2013-01-14T10:00'], prefix: 'gt'}]]
  # ['parameter=ge2013-01-14', [{name: 'parameter', value: ['2013-01-14'], prefix: 'ge'}]]

  # # strings
  # ['name=eve', [{name: 'name', value: ['eve']}]]
  # ['name:contains=Eve', [{name: 'name', value: ['Eve'], modifier: 'contains'}]]
  # ['name:exact=Eve', [{name: 'name', value: ['Eve'], modifier: 'exact'}]]

  # # # urls
  # ['url=http://acme.org/fhir/ValueSet/123', [{name: 'url', value: ['http://acme.org/fhir/ValueSet/123']}]]
  # ['url:below=http://acme.org/fhir/', [{name: 'url', value: ['http://acme.org/fhir/'], modifier: 'below'}]]

  # # # codes
  # ['parameter=code', [{name: 'parameter', value: ['code']}]]
  # ['parameter=|code', [{name: 'parameter', value: [['','code']]}]]
  # ['parameter=system|code', [{name: 'parameter', value: [['system', 'code']]}]]

  # ['identifier=http://acme.org/patient|2345', [{name: 'identifier', value: [['http://acme.org/patient','2345']]}]]
  # ['gender=male', [{name: 'gender', value: ['male']}]]
  # ['gender:not=male', [{name: 'gender', value: ['male'], modifier: 'not'}]]
  # ['active=true', [{name: 'active', value: ['true']}]]
  # ['code=http://acme.org/conditions/codes|ha125', [{name: 'code', value: [['http://acme.org/conditions/codes','ha125']]}]]
  # ['code=ha125', [{name: 'code', value: ['ha125']}]]
  # ['code:text=headache', [{name: 'code', value: ['headache'], modifier: 'text'}]]
  # ['code:in=http%3A%2F%2Fsnomed.info%2Fsct%3Ffhir_vs%3Disa%2F126851005', [{name: 'code', value: ['http://snomed.info/sct?fhir_vs=isa/126851005'], modifier: 'in'}]]
  # ['code:below=126851005', [{name: 'code', value: ['126851005'], modifier: 'below'}]]
  # ['code:in=http://acme.org/fhir/ValueSet/cardiac-conditions', [{name: 'code', value: ['http://acme.org/fhir/ValueSet/cardiac-conditions'], modifier: 'in'}]]

  # # # quantities
  # ['value=5.4|http://unitsofmeasure.org|mg', [{name: 'value', value: [['5.4','http://unitsofmeasure.org','mg']]}]]
  # ['value=5.4||mg', [{name: 'value', value: [['5.4','', 'mg']]}]]
  # ['value=le5.4|http://unitsofmeasure.org|mg', [{name: 'value', value: [['5.4','http://unitsofmeasure.org','mg']],prefix: 'le'}]]
  # ['value=ap5.4|http://unitsofmeasure.org|mg', [{name: 'value', value: [['5.4','http://unitsofmeasure.org','mg']],prefix: 'ap'}]]

  # # refs
  # ['subject=Patient/23',[{name: 'subject', value: ['Patient/23']}]]
  # ['subject:Patient=23',[{name: 'subject', value: ['Patient/23']}]]
  # ['subject:Patient.name=peter',[{chain: [['subject', 'Patient']], name: 'name', value: ['peter']}]]

  # ['component-code-value-quantity=http://loinc.org|8480-6$lt60',[{name: '', value: [[['http://loinc.org', '8480-6'], ['lt60']]]}]]

  # ['characteristic-value=gender$mixed',[{name: '', value: [['gender', 'mixed']]}]]
  # ['_filter=name eq http://loinc.org|1234-5 and subject.name co "peter"',[{name: '', value: []}]]
  # ['_sort:asc=_score',[{name: '', value: []}]]
  # ['_include=MedicationOrder:patient',[{name: '', value: []}]]
  # ['_revinclude=Provenance:target',[{name: '', value: []}]]
  # ['_include=MedicationDispense.authorizingPrescription&_include:recurse=MedicationOrder.prescriber',[{name: '', value: []}]]
  # ['_elements=identifier,active,link',[{name: '', value: []}]]
]

describe "Params", ()->
 it "simple", ()->
   for [k,v] in specs
     expect(params.parse(k)).toEqual(v)
