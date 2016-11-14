extractInt = (base_url, regex)->
  matched = base_url.match(regex)
  matched && matched[1] && parseInt(matched[1])

exports.search_links = (query, expr, total)->
  # <http://www.hl7.org/implement/standards/fhir/search.html#2.1.1.2>,
  # <http://www.hl7.org/implement/standards/fhir/http.html#summary>:
  # `GET [base]/[resourcetype]?name=value&...`
  base_url = "/#{query.resourceType}?#{query.queryString}"

  res = []

  if base_url.indexOf('_page=') < 0
    base_url = base_url + "&_page=0"

  requested_count = expr.count
  requested_page = expr.page ? 0

  res.push({relation: 'self', url: base_url})

  if requested_count && requested_count * (requested_page + 1) < total
    next_url = base_url.replace /_page=\d+/, -> "_page=#{requested_page + 1}"
    res.push({relation: 'next', url: next_url})

  if requested_page && requested_page >= 1
    next_url = base_url.replace /_page=\d+/, -> "_page=#{requested_page - 1}"
    res.push({relation: 'previous', url: next_url})

  if requested_count
    last_page = Math.max(0, Math.ceil(total / requested_count) - 1)
    last_url = base_url.replace /_page=\d+/, -> "_page=#{last_page}"
    res.push({relation: 'last', url: last_url})

  res

exports.postprocess_resource = (resource)->
  resource
