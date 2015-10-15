exports.to_range = (date)->
  return null unless date
  date = date.toString()
  return null if date.trim() == ''

  switch date.length
    #2010
    when 4
      y = parseInt(date)
      "[#{y}-01-01,#{y+1}-01-01)"

    #2010-02
    when 7
      y1 = y2 = parseInt(date.substring(0, 4))
      m  = m1 = parseInt(date.substring(5))
      m2 = m+1
      if m < 8
        m1 = "0"+m; m2 = "0"+(m+1)
      else if m == 9
        m1 = "0"+m
      else if m == 12
        m2 = "01"; y2 = y1+1

      "[#{y1}-#{m1}-01,#{y2}-#{m2}-01)"

    #2010-02-03
    when 10 then "[#{date},#{date}T23:59:59.99999]"

    #2010-02-03T10
    when 13 then "[#{date}:00,#{date}:59:59.99999]"

    #2010-03-05T23:50
    when 16 then "[#{date},#{date}:59.99999]"

    #2010-03-05T23:50:30
    when 19 then "[#{date},#{date}.99999]"

    else
      throw new Error("date.to_range: Don't know how to handle #{date}")

to_sql_date = (x)->
  return null unless x
  if x.length == 4
    "#{x}-01-01"
  else if x.length == 7
    "#{x}-01"
  else
    throw new Error("Not implemented: could not parse #{x} as date")

exports.normalize =  to_sql_date

exports.range = (start, ending)->
  if ending == 'infinity'
    "(#{to_sql_date(start)},infinity]"
  else
    throw new Error("Imlement me")
