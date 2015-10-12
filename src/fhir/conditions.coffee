TODO = 'TODO'
TABLE =
  boolean:
    token: TODO
  code:
    token: TODO
  date:
    date:
      eq: TODO
      ne: TODO
      gt: TODO
      lt: TODO
      ge: TODO
      le: TODO
      sa: TODO
      eb: TODO
      ap: TODO
  dateTime:
    date:
      eq: TODO
      ne: TODO
      gt: TODO
      lt: TODO
      ge: TODO
      le: TODO
      sa: TODO
      eb: TODO
      ap: TODO
  instant:
    date: TODO
  integer:
    number: TODO
  decimal:
    number: TODO
  string:
    string: TODO
    token: TODO
  uri:
    reference: TODO
    uri: TODO
  Period:
    date: TODO
  Address:
    string: TODO
  Annotation: null
  CodeableConcept:
    token: TODO
  Coding:
    token: TODO
  ContactPoint:
    token: TODO
  HumanName:
    string:
      eq: (opts)->
        call =
          call: extract_fn(opts.searchType, opts.array)
          args: [':resource', JSON.stringify(opts.path), opts.elementType]
          cast: 'text'
        [':=', call, ':true']
  Identifier:
    token: TODO
  Quantity:
    number: TODO
    quantity: TODO
  Duration: null
  Range: null
  Reference:
    reference: TODO
  SampledData: null
  Timing:
    date: TODO

extract_fn = (resultType, array)->
  res = []
  res.push('fhir.extract_as_')
  res.push(resultType.toLowerCase())
  if array
    res.push('_array')
  res.join('')

module.exports.condition = (opts)->
  handler = TABLE[opts.elementType]
  throw new Error("#{opts.elementType} is not suported") unless handler
  handler = handler[opts.searchType]
  throw new Error("#{opts.elementType} #{opts.searchType} is not suported") unless handler
  console.log(opts)
  handler(opts)
