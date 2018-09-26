lang = require('../lang')
lisp = require('../lispy')


OPERATORS_REG =/^(eq|ne|gt|lt|ge|le|sa|eb|ap)[0-9]/
VALUE_SEP_REG= /\||\$/

# parse key
parse_param_left = (x)->
  [name, modifier] = decodeURIComponent(x).split(':')
  lang.merge({}, {name: name, modifier: modifier})

parse_chained_left = (x)->
  chain = x.split('.')
  x = chain.pop()
  chain = chain.map((x)-> x.split(':'))
  [name, modifier] = decodeURIComponent(x).split(':')
  lang.merge({}, {name: name, modifier: modifier, chain: chain})

parse_rchained_left = (x)->
  [resource, link, x] = x.split(':')
  [name, modifier] = decodeURIComponent(x).split(':')
  if name && name.indexOf('.') > -1
      throw new Error("Chained name is not supported in reverse chaining: #{name}")
  if modifier && modifier.length
      throw new Error("Modifiers is not supported in reverse chaining: #{modifier}")
  lang.merge({}, {name: name, modifier: modifier, chain: [[resource, link]]})

parse_right =(x)->
  x.split(',').map(parse_one_value)


parse_one_value = ( x)->
  x = decodeURIComponent(x)
  match =  OPERATORS_REG.exec(x)
  res = {}
  if match && match[1]
    res.prefix = match[1]
    x = x.substring(2)
  res.value = x
  res

special_parameters = [
  '_id'
  '_lastUpdated'
  '_tag'
  '_profile'
  '_security'
  '_text'
  '_content'
  '_list'
]

is_special_param = (k)-> special_parameters.indexOf(k) > -1

mk_include = (direction)->
  (query, left, right)->
    includes = right.split(',')
      .map((x)-> x.trim())
      .filter(identity)
      .map (x)->
        parts = x.split(':')
        if direction == 'include'
          meta = switch parts.length
            when 1
              {resourceType: query.query, name: parts[0]}
            when 2
              {resourceType: parts[0], name: parts[1]}
            when 3
              {resourceType: parts[0], name: parts[1], target: parts[2]}
            else
              throw new Error("Wrong format of _include #{JSON.stringify(parts)}")
        else if direction == 'revinclude'
          meta = switch parts.length
           when 2
              {resourceType: parts[0], name: parts[1], target: query.query}
            when 3
              {resourceType: parts[0], name: parts[1], target: parts[2]}
            else
              throw new Error("Wrong format of _include #{JSON.stringify(parts)}")
        else
          throw new Error("Guard")
        ['$param', meta, 'placeholder']
    query[direction] = query[direction] || []
    Array.prototype.push.apply(query[direction], includes)
    query

specials =
  limit: (query, left, right)->
    query.limit = parseInt(right)
    query
  count: (query, left, right)->
    query.count = parseInt(right)
    query
  page: (query, left, right)->
    query.page = parseInt(right)
    query
  elements: (query, left, right)->
    query.elements = right.split(',').map((x)-> x.trim()).filter(identity)
    query
  summary: (query, left, right)->
    query.summary = true
    query
  id: (query, left, right)->
    ids = right.split(',').map((identifier)->
      i = identifier.trim()

      # If `identifier` like http://fhirbase/Patient/id
      if typeof(i) == 'string' && /^http/.test(i)
        a = i.split('/')

        if a[a.length - 2] == '_history'
          # If `identifier` like this:
          # "https://fhirbase/Patient/id/_history/id"
          i = a[a.length - 3]
        else
          # If `identifier` like this:
          # "http://fhirbase/Patient/id"
          i = a[a.length - 1]

      i
    )

    query.ids = ids.filter(identity)
    query
  include: mk_include('include')
  revinclude: mk_include('revinclude')
  sort: (query, left, right)->
    key = right
    key = "#{key}:#{left}" if left
    query.sort ||= []
    query.sort.push ['$param', key, '']
    query
  totalMethod: (query, left, right)->
    query.total_method = right;
    query
  format: (query, left, right)->
    query
  lastUpdated: (query, left, right)->
    unless query.lastUpdateds
      query.lastUpdateds = []

    # Search with `prefixes` <https://www.hl7.org/fhir/search.html#prefix>.
    query.lastUpdateds.push(
      if right.match(/^[0-9]/)
        operator: 'eq'
        value: right
      else if right.match(OPERATORS_REG)
        operator: right.substring(0, 2),
        value: right.substring(2, right.length)
      else
        throw new Error("""
          Search by "lastUpdated" against "#{right}" not implemented
        """)
    )
    query

grouping = (acc, expr)->
  result = acc
  joins = []
  where = ['$and']
  for form in expr
    key = form[0]
    if key == '$param'
      where.push(form)
    else if key == '$chained'
      joins.push(form)
    else if key == '$rchained'
      joins.push(form)
    else if is_special_param(key)
      where.push form
    else
      args = form[1...]
      parser = specials[key]
      throw new Error("No parser for special - #{key}") unless parser
      result = parser.apply(null, [result].concat(args))
  result.where = where if where.length > 1
  result.joins = joins if joins.length > 0
  result

typed = ([l,r])->
  if l.indexOf('_has:') == 0
    ['$rchained', l.substring(5), r]
  else if l.indexOf('.') > -1
    ['$chained', l, r]
  else if l.indexOf('_') == 0
    [key,mod] = l.split(':')
    key = key.replace(/^_/, '')
    [key, mod, r]
  else
    ['$param', l, r]

identity = (x)-> x

exports.parse = (resourceType, str) ->
  # If `str` like http://fhirbase/foo/bar?identifier=123
  if typeof(str) == 'string' && /^http/.test(str)
    a = str.split('?')
    a.shift()
    str = a.join('?')

  pairs = str.trim().split("&").filter(identity).map(
      (x)->
          parts = x.trim().split('=')
          [parts.shift(), parts.join('=')]
  ).map(typed)
  result = {query: resourceType}
  expr = grouping(result, pairs)
  forms =
    $param: (l, r)->
      if lang.isObject(l)
        left = l
      else
        left = parse_param_left(l)
        left.resourceType = resourceType
      if lang.isObject(r)
        right = r
      else
        right = parse_right(r)

      if right.length == 1
        ['$param', left, right[0]]
      else
        ['$or'].concat(right.map((x)-> ['$param', lang.clone(left), x]))
    $chained: (l, r)->
      left = parse_chained_left(l)
      right = parse_right(r)

      form = ['$chained']
      chain = left.chain
      item = null
      currentResourceType = resourceType
      for [element, rt] in chain
        item = ['$param', {resourceType: currentResourceType, name: element, join: rt}, {value: '$id'}]
        form.push(item)
        currentResourceType = rt
      meta = {resourceType: currentResourceType, name: left.name}
      meta.modifier = left.modifier if left.modifier
      if right.length == 1
        form.push ['$param', meta, right[0]]
      else
        form.push ['$or'].concat(right.map((x)-> ['$param', lang.clone(meta), x]))
      form
    $rchained: (l, r)->
      left = parse_rchained_left(l)
      right = parse_right(r)

      form = ['$rchained']
      chain = left.chain
      item = null
      currentResourceType = resourceType
      for [element, rt] in chain
        item = ['$param', {resourceType: element, name: rt, join: currentResourceType, reverse: true}, {value: '$id'}]
        form.push(item)
        currentResourceType = element
      meta = {resourceType: currentResourceType, name: left.name}
      meta.modifier = left.modifier if left.modifier
      if right.length == 1
        form.push ['$param', meta, right[0]]
      else
        form.push ['$or'].concat(right.map((x)-> ['$param', lang.clone(meta), x]))
      form

  lisp.eval_with(forms, expr)
