helpers = require('../fhir/search_helpers')
lang = require('../lang')

exports.history_bundle  = (resources)->
  resourceType: "Bundle"
  total: resources.length
  meta: {lastUpdated: new Date()}
  type: 'history'
  entry: resources.map (x)->
    entry = {}

    if lang.isArray(x.meta.extension)
      requestMethod = x.meta.extension.filter(
        (e) -> e.url == 'fhir-request-method'
      )[0].valueString

      requestUri = x.meta.extension.filter(
        (e) -> e.url == 'fhir-request-uri'
      )[0].valueUri

      entry = {
        request: {
          method: requestMethod,
          url: requestUri
        }
      }

    if requestMethod != 'DELETE'
      entry.resource = helpers.postprocess_resource(x)

    entry

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
