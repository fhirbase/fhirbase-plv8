# Patient.active
extract_token(resource, ['active'], 'boolean')::text = 'true'

# Patient.gender
extract_token(resource, ['gender'], 'code')::text = 'male'

extract_token_as_array(resource, ['identifier']) => ['5555', 'MRN|5555', '66666', 'INN|6666']
&& ['5555']
&& ['MRN|5555']
&& ['MRN|5555', 'INN|6666']  identifier=MRN|5555,INN|6666

<@ ['MRN|5555', 'INN|6666']  identifier=MRN|555&identifier=INN|6666
(&&| <@) ['MRN|5555'] AND (&&|<@) ['INN|6666']  identifier=MRN|555&identifier=INN|6666



birthdate=2010
{birthDate: '2010-06'}

extract_as_datetime_range(resource, ['birthDate']) => '[2010-06-01,2010-07-01)'::daterange

extract::daterange && '[2010-01-01,2011-01-01)'::daterange

birthdate=lt1940
{birthDate: '1960-06'}
extract_as_datetime_range(resource, ['birthDate']) => '[1960-06-01,1960-07-01)'::daterange
extract::daterange && (-ininity, 1941-01-01)


extact_as_number(resource, path) ><= value

extact_as_quantity_as_number(resource, path) ><=~ value



{name: [{given: ['marat', 'maratka', 'marik']}]}
given=marat

extract_as_text(resource, ['name','given'], 'string[]') ilike '%marat%'

given:exact=marik

extract_as_text_array(resource, ['name','given'], 'string[]') => ['marat', 'maratka', 'marik']

&& ['maratka']

given=ewrik
extract_as_text(resource, ['name','given'], 'string[]') => '@@marat@@ @@maratka@@ @@marik@@'
ilike 'rik@@'
