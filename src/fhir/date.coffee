exports.to_lower_date = (date)->
  return null unless date
  date = date.toString()
  return null if date.trim() == ''
  return date if date == '-infinity'

  switch date.length
    #2010
    when 4
      y = parseInt(date)
      "#{y}-01-01"
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

      "#{y1}-#{m1}-01"
    #2010-02-03
    when 10 then date
    #2010-02-03T10
    when 13 then "#{date}:00"
    #2010-03-05T23:50
    when 16 then date
    #2010-03-05T23:50:30
    when 19 then date
    else
      throw new Error("date.to_range: Don't know how to handle #{date}")

exports.to_upper_date = (date)->
  return null unless date
  date = date.toString()
  return null if date.trim() == ''
  return date if date == 'infinity'

  switch date.length
    #2010
    when 4
      y = parseInt(date)
      "#{y+1}-01-01"

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

      "#{y2}-#{m2}-01"

    #2010-02-03
    when 10 then "#{date}T23:59:59.99999"

    #2010-02-03T10
    when 13 then "#{date}:59:59.99999"

    #2010-03-05T23:50
    when 16 then "#{date}:59.99999"

    #2010-03-05T23:50:30
    when 19 then "#{date}.99999"

    else
      throw new Error("date.to_range: Don't know how to handle #{date}")

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

exports.range = (start, ending)->
  if ending == 'infinity'
    "(#{to_lower_date(start)},infinity]"
  else if start == 'infinity'
    "[-infinity, #{to_upper_date(start)}]"
  else
    throw new Error('Unhandled case')
