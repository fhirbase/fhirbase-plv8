exports.search_links = (query, count)->
  base_url = "#{query.resourceType}/#{query.queryString}"
  [
    {relation: 'self', url: base_url }
    # {relation: 'previous', url: base_url }
    # {relation: 'next', url: base_url }
    # {relation: 'last', url: base_url }
  ]

exports.postprocess_resource = (resource)->
  if resource.meta && resource.meta.request
    delete resource.meta.request
  resource
