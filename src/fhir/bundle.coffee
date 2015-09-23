exports.history_bundle  = (resources)->
  resourceType: "Bundle"
  id: "???"
  total: resources.length
  meta: {lastUpdated: new Date()}
  type: 'history'
  link: [{ realtion: 'self', url: '???'}]
  entry: resources.map (x)->
    fullUrl: '???'
    resource: x
