exports.parse = (str)->

# name co "pet"
# => ['contains', 'name', 'pet']

# given eq "peter"
# => ['equal', 'given', 'peter']

# name eq http://loinc.org|1234-5
# => ['equal', ['param', 'name'], ['list', 'http://loinc.org','1234-5']]

# subject.name co "pet"
# => ['contains', ['chain', 'subject', 'name'], 'pet']

# related[type eq "has-component"].target pr true
# => ['empty', ['related', ['equal', ['param', 'type'], 'has-component']],
#              'true']

# related[type eq has-component].target re Observation/4
# => ['references', ['related', ['equal', 'type', 'has-component']],
#                   'Observation/4']
#
# name co "pet" and name ew 'ups'
# => ['and', ['equal', 'name', 'pet'],
#            ['end_with', 'name', 'ups']]
