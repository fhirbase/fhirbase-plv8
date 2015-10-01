# _expressions lookup table
# paramType:
#   elementType:
#     operator:

_expressions =
  _else:
    _else:
      _else: (tbl, p)-> throw new Exception("Not implemented for #{p}")
  number: {}
  token: {}
  reference: {}
  composite: {}
  quantity: {}
  uri: {}
  datetime:
    _else: (x)-> '????'
  date:
    date:
      gt: (tbl, p)-> "#{tbl}.#{p.param.name} in #{p.value}"
      _else: (tbl, p)-> "#{tbl}.#{p.param.name} = #{p.value}"
  string:
    _else:
      _else: (tbl, p)-> "#{tbl}.#{p.param.name} ilike '%#{p.value}%'"
    humanname:
      eq: (tbl, p)-> "#{tbl}.#{p.param.name} ilike #{p.value}"
      _else: (tbl, p)-> "#{tbl}.#{p.param.name} = #{p.value}"

_table_name = (rt)-> rt.toLowerCase()

_joins = (tbl, q)->
  return "" unless q.joins
  res = for k,v of q.joins
    next_tbl = _table_name(v.resourceType)
    """
    JOIN #{next_tbl} ???
      ON reference(#{tbl}, #{k}) = #{next_tbl}.logical_id
     AND #{_conds(v)}
         #{_joins(next_tbl,v)}
    """
  res.join "\n"

_cond_expression = (tbl, p)->
  etype = _expressions[p.param.type] || _expressions._else
  op = etype[p.element.type.toLowerCase()] || etype._else
  proc = op[p.operator] || op._else
  proc(tbl, p)

_conds = (q)->
  tbl = _table_name(q.resourceType)
  res = for p in q.params[1..]
    _cond_expression(tbl, p)
  if res.length > 0
    " #{res.join(" AND ")}"

_where = (q)->
  res = _conds(q)
  if res then " WHERE #{res} " else ""

# Ask FHIR group about _page?????
_paging = (q)->
  res = q.result || {}
  count = res.count || 100
  page_num = res.page || 0
  offset = page_num * count
  " LIMIT #{count} OFFSET #{offset}"

_order = (q)->
  res = ((q.result || {}).sort || [])
    .map ([dir, col])->
      "#{col} #{dir}"
    .join(", ")
  if res
    " ORDER BY #{res} "
  else
    ""

_query = (q)->
  tbl = _table_name(q.resourceType)
  """
  SELECT *
    FROM #{tbl}
  #{_joins(tbl, q)}
  #{_where(q)}
  #{_order(q)}
  #{_paging(q)}
  """

exports.sql = _query

"""
Search result parameters

_sort
_count
_include
_revinclude
_summary
_contained
_containedType
"""

"""
for all resources

_id
_language?
_lastUpdated
_profile
_security
_tag
_text
"""

"""
Special case
_filter
"""
