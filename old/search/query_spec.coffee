q = require('../../src/search/query').sql

console.log q

tq =
  resourceType: 'Patient'
  customQuery:
    name: '????'
    params: []
  result:
    sort: [
      ['asc', 'name']
      ['desc', 'birthDate']
    ]
    count: 10
    revincludde: []
    summary: true # false
    include: [
      'MedicationDispense.authorizingPrescription',
      'MedicationPrescription.prescriber'
    ]
  params: [
    'AND',
    {param:
      name: 'name'
      type: 'string'
     element:
       path: 'Patient.name'
       type: 'HumanName',
     operator: 'eq' # means operator + modifier
     value: 'ivan'},
    {param:
      name: 'birthdate'
      type: 'date'
     element:
       path: 'Patient.birthDate'
       type: 'date'
     operator: 'gt'
     value: '1980'}]

res = q(tq)
console.log res
console.log " "

describe "A suite", ()->
  it "contains spec with an expectation", ()->
    # nop
    #

"""
 SELECT  *
 FROM patient
 WHERE (
  (idx.index_as_date(content, '{birthDate}'::text[], 'date'::text) && '["1980-01-01 00:00:00+03",)'))
  AND
  (idx.index_as_string(patient.content, '{name}') ilike '%ivan%')
 LIMIT 100                                                                                                                                               +
 OFFSET 0
"""

querySchema =
  resourceType: 'ResourceType'
  on: 'Join condition? calculatable'
  # ??? use params
  joins:
    searchReference: querySchema
    searchReference2: querySchema
  params: [
    'and' #logical grouping
    param: # search parameter type
      name: 'param name'
      type: 'param type'
    element: #element path
      path: 'path to element i.e. Patient.name'
      type: 'type of element'
  ]

query =
  resourceType: 'Encounter',
  params: [
    'and',
     {param:
       name: 'name'
       type: 'string'
     element:
       path: 'Patient.name'
       type: 'HumanName'
     operator: '=',
     value: ['x','y']},
     {param:
       name: 'birth'
       type: 'date'
     element:
       path: 'Patient.birthDate'
       type: 'date'
     operator: '=',
     value: ['x','y']}
  ]
  joins:
    subject:
      resourceType: 'Patient'
      on: ["logical_ids(content, '{subject}')", "logical_id"]
      params:[
        'and',
        param: {name: 'name', type: 'string'}
        element: {path: 'Patient.name', type: 'HumanName'}
        operator: '='
        value: ['x','y']

        param: {name: 'name', type: 'string'}
        element: {path: 'Patient.name', type: 'HumanName'}
        operator: '='
        value: ['x','y']
      ]
      joins:
        organization:
          resourceType: 'Organization'
          on: ["logical_ids(content, '{subject}')", "logical_id"]
          params:[
            'and',
            param: {name: 'title', type: 'string'}
            element: {path: 'Organization.name', type: 'string'}
            operator: '='
            value: ['x']
          ]

console.log q(query)
