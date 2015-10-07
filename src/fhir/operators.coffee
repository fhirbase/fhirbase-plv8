SUPPORTED = [
  'eq' #an item in the set has an equal value
  'ne' #An item in the set has an unequal value
  'co' #An item in the set contains this value
  'sw' #An item in the set starts with this value
  'ew' #An item in the set ends with this value
  'gt' #
  'lt' #
  'ge' #
  'le' #
]

CANDIDATS = [
  'ap' #A value in the set isis approximately the same as this value.
  'sa' #The value starts after the specified value
  'eb' #The value ends before the specified value
  'in' #True if one of the concepts is in the nominated value set by URI, either a relative, literal or logical vs
  'ni' #True if none of the concepts are in the nominated value set by URI, either a relative, literal or logical vs
  're' #relativeTrue if one of the references in set points to the given URL
  'pr' #The set is empty or not (value is false or true)
]

UNSUPPORTED = [
  'po' #True if a (implied) date period in the set overlaps with the implied period in the value
  'ss' #True if the value subsumes a concept in the set
  'sb' #True if the value is subsumed by a concept in the set
]

fhirbase_ops = [
  'string_array_to_string_ilike'
  'string_array_inclusion'
]

eparams  -> operator path value type

