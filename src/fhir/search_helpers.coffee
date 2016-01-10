extractInt = (base_url, regex)->
  matched = base_url.match(regex) 
  matched && matched[1] && parseInt(matched[1])

exports.search_links = (query, total)->
  base_url = "#{query.resourceType}/#{query.queryString}"
  res = []

  if base_url.indexOf('page=') < 0
    base_url = base_url + "&page=1"

  requested_count = extractInt(base_url, /count=(\d+)/) 

  requested_page = extractInt(base_url, /page=(\d+)/)

  res.push({relation: 'self', url: base_url})

  if requested_count && requested_count < total
    next_url = base_url.replace /page=\d+/, -> "page=#{requested_page + 1}"
    res.push({relation: 'next', url: next_url})

  if requested_page && requested_page > 1
    next_url = base_url.replace /page=\d+/, -> "page=#{requested_page - 1}"
    res.push({relation: 'previous', url: next_url})

  if requested_count
    last_page = if requested_count < total
        Math.floor(total / requested_count) + 1
      else
        requested_page

    last_url = base_url.replace /page=\d+/, -> "page=#{last_page}"
    res.push({relation: 'last', url: last_url})

  res

exports.postprocess_resource = (resource)->
  resource
