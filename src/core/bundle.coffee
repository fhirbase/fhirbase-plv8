helpers = require('../fhir/search_helpers')
exports.history_bundle  = (resources)->
  resourceType: "Bundle"
  id: "???"
  total: resources.length
  meta: {lastUpdated: new Date()}
  type: 'history'
  link: [{ realtion: 'self', url: '???'}]
  entry: resources.map (x)->
    fullUrl: '???'
    resource: helpers.postprocess_resource(x)


# exports.search_bundle  = (query, resources)->
#   resourceType: "Bundle"
#   id: "???"
#   total: resources.length
#   meta: {lastUpdated: new Date()}
#   query: query
#   type: 'search'
#   link: [{ realtion: 'self', url: '???'}]
#   entry: resources.map (x)->
#     fullUrl: '???'
#     resource: helpers.postprocess_resource(x)
