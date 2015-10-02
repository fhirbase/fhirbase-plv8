# cases

# Patient.active
# 1 to 1; primitive
# (resource->>'active')::boolean [= <> is null]
# not selective; we do not need index for such type

# address-city

# 1 to *; complex
# a)
#   (resource#>>'{address,0,city}') ilike ~ =
#   (resource#>>'{address,1,city}') ilike ~ =
#   (resource#>>'{address,2,city}') ilike ~ =
#   (resource#>>'{address,3,city}') ilike ~ =
# we need trigram and/or fulltext index
# separate index for each index - starting from 0 and accumulating statistic
#
#  pro: more accurate result
#  contra: quite complex solution
#
# b)
#   use GIN (expr::text[]) gin_trgm_ops) or GIST
#   GIN (extract(resource, paths,opts)::text[] gin_trgm_ops)
#   one index for parameter
#
# NOTES: we need umlauts normalization for strings
TABLE = require('./conditions')

exports.build_conditions = (opts)->

exports.condition = (opts)->
  handler = TABLE[opts.elementType]
  throw new Error("Unsupported #{opts.elementType}") unless handler
  handler = handler[opts.searchType]
  throw new Error("Unsupported #{opts.elementType} #{opts.searchType}") unless handler
  handler = handler[opts.operation]
  throw new Error("Unsupported #{opts.elementType} #{opts.searchType} #{opts.operation}") unless handler
  handler(opts)

exports._search = (plv8, query)->
  []


exports.search = (plv8, query)->
  parse(query.queryString)
