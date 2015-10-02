extract_fn = (resultType, array)->
  res = []
  res.push('fhir.extract_as_')
  res.push(resultType.toLowerCase())
  if array
    res.push('_array')
  res.join('')

module.exports =
  boolean:
    $nonIndexable: false
    token:
      eq: (opts)->
        call =
          call: extract_fn(opts.searchType, opts.array)
          args: [':resource', JSON.stringify(opts.path), opts.elementType]
          cast: 'boolean'
        [':=', call, ':true']
  HumanName:
    string:
      eq: (opts)->
        call =
          call: extract_fn(opts.searchType, opts.array)
          args: [':resource', JSON.stringify(opts.path), opts.elementType]
          cast: 'text[]'
        value =
            value: opts.value
            array:true
            cast: 'text[]'
        [':&&', call, value]
