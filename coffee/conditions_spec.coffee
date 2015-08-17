plv8 = require('./plv8')
p = (x)-> console.log(JSON.stringify(x))
subj = require('./conditions.coffee')

cnd = subj.CONDITIONS

SAMPLES = [
  [['identifier', 'any'],
   {table_name: "patient", value: ['aa', 'bb']},
   "(\"patient\".logical_id IN('aa','bb'))"]

  [['identifier', 'any'],
   {table_name: "patient", value: ["a'a", 'bb']},
   "(\"patient\".logical_id IN('a''a','bb'))"]

  [['string', 'eq'],
   {table_name: "patient", value: ['aa'], path: ['name', 'given']},
   "(fhirbase_idx_fns.index_as_string_eq(\"patient\".content, ARRAY['name','given']) ilike '%aa%')"]

  [['string', 'eq'],
   {table_name: "patient", value: ['aa', 'bb'], path: ['name', 'given']},
   "(fhirbase_idx_fns.index_as_string_eq(\"patient\".content, ARRAY['name','given']) ilike '%aa%' OR fhirbase_idx_fns.index_as_string_eq(\"patient\".content, ARRAY['name','given']) ilike '%bb%')"]

  [['string', 'exact'],
   {table_name: "patient", value: ['aa', 'bb'], path: ['name', 'given']},
   "(fhirbase_idx_fns.index_as_string_exact(\"patient\".content, ARRAY['name','given']) && ARRAY['aa','bb'])"]

  [['token', 'eq'],
   {table_name: "patient", is_primitive: true, value: ['aa', 'bb'], path: ['a', 'b']},
   "(fhirbase_idx_fns.index_primitive_as_token(\"patient\".content, ARRAY['a','b']) && ARRAY['aa','bb'])"]

  [['reference', 'any'],
   {table_name: "patient", value: ['aa', 'bb'], path: ['a', 'b']},
   "(fhirbase_idx_fns.index_as_reference(\"patient\".content, ARRAY['a','b']) && ARRAY['aa','bb'])"]

  [['date', 'eq'],
   {table_name: "patient", type: 'Date', value: ['2011'], path: ['birthDate' ]},
   "(fhirbase_date_idx.index_as_date(\"patient\".content, ARRAY['birthDate'], 'Date'::text) && '[2011, infinity)')"]

  [['date', 'gt'],
   {table_name: "patient", type: 'Date', value: ['2011'], path: ['birthDate' ]},
   "(fhirbase_date_idx.index_as_date(\"patient\".content, ARRAY['birthDate'], 'Date'::text) && '[2011, 2012)')"]

  [['date', 'lt'],
   {table_name: "patient", type: 'Date', value: ['2011'], path: ['birthDate' ]},
   "(fhirbase_date_idx.index_as_date(\"patient\".content, ARRAY['birthDate'], 'Date'::text) && fhirbase_date_idx._datetime_to_tstzrange('2011', NULL))"]
   '(fhirbase_date_idx.index_as_date(\"patient\".content, ARRAY['birthDate'], 'Date'::text) && ('(,' || fhirbase_date_idx._date_parse_to_upper('2011') || ']' )::tstzrange)' to equal '(fhirbase_date_idx.index_as_date(\"patient\".content, ARRAY['birthDate'], 'Date'::text) && fhirbase_date_idx._datetime_to_tstzrange('2011', NULL))'.
  ]

get_in = (obj, pth)->
  return obj if pth.length == 0
  nobj = obj[pth[0]]
  get_in(nobj, pth[1..-1]) if nobj

describe "param parser", ->
  it 'identifier', ->
    for [x,y,z] in SAMPLES
      fn = get_in(cnd, x)
      throw "No #{x} fn" unless fn
      expect(fn(plv8, y)).toEqual(z)
