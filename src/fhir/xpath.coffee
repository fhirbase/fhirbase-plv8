parse_pred = (x)->
  x.split('=').map((x)-> x.replace(/'/g,''))

parse_one = (str)->
  state = 'normal'
  res = []
  pred = []
  current = []
  push = ()->
    path_item  = current.join('').replace(/^f:/,'')
    if pred.length > 0
      res.push([path_item, parse_pred(pred.join(''))])
    else
      res.push(path_item)
    current = []

  for x in str
    switch state
      when 'predicat'
        if x == ']' then state == 'normal' else pred.push(x)
      when 'normal'
        switch x
          when '/' then push()
          when '[' then state = 'predicat'
          else current.push(x)
  push()
  res[1..]

exports.parse = (xpath)->
  return unless xpath
  xpath.split(' | ').map(parse_one)
