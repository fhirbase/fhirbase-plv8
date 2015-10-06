# index of search parameters by resourceType-name
# for quick meta data retrieval
# requires elements_index to work
module.exports.new = (getter, elements_index)->
  idx =
    get: (tp)->
      console.log('ups')

module.exports.find = (idx, resourceType, name)->
  key = "#{resourceType}-#{name}"
  # unless idx[key]
  # TODO
  idx[key]

