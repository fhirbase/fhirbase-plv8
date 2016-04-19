extract_tz = (date)->
  tz = ''
  date_length = date.length
  if date.indexOf('Z') == date_length - 1 
    tz = 'Z'
    date = date.substring(0, date_length - 1)
  else if date.length > 10 and date.match(/[+|-](0[0-9]|1[0-3])$/)
    tz = date.substring(date_length - 3, date_length)
    date = date.substring(0, date_length - 3)
  else if date.length > 10 and date.match(/[+|-](0[0-9]|1[0-3])[034][05]$/) # fix #82 <https://github.com/fhirbase/fhirbase-plv8/issues/82>
    tz = date.substring(date_length - 5, date_length)
    date = date.substring(0, date_length - 5)
  else if date.length > 10 and date.match(/[+|-](0[0-9]|1[0-3]):[034][05]$/) # fix #72 <https://github.com/fhirbase/fhirbase-plv8/issues/72>
    tz = date.substring(date_length - 6, date_length)
    date = date.substring(0, date_length - 6)
  [date, tz]

extract_msecs = (date, pad_with)->
  msecs = date.match(/[.][0-9]+$/)
  return [date, ".#{pad_with.substring(0,5)}"] unless msecs
  msecs = msecs[0]
  [date.replace(msecs, ''), msecs + pad_with.substring(0, 6 - msecs.length)]

exports.to_lower_date = (date)->
  return null unless date
  date = date.toString()
  return null if date.trim() == ''
  return date if date == '-infinity'

  [date, tz] = extract_tz(date)

  if date.length > 16
    [date, ms] = extract_msecs(date, "00000")
  else
    ms = ''

  switch date.length
    #2010
    when 4
      y = parseInt(date)
      "#{y}-01-01#{tz}"
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

      "#{y1}-#{m1}-01#{tz}"
    #2010-02-03
    when 10 then "#{date}#{tz}"
    #2010-02-03T10
    when 13 then "#{date}:00#{tz}"
    #2010-03-05T23:50
    when 16 then "#{date}:00.00000#{tz}"
    #2010-03-05T23:50:30
    when 19 then "#{date}#{ms}#{tz}"
    else
      throw new Error("date.to_range: Don't know how to handle #{date}")

exports.to_upper_date = (date)->
  return null unless date
  date = date.toString()
  return null if date.trim() == ''
  return date if date == 'infinity'

  [date, tz] = extract_tz(date)
  ms = ''
  if date.length > 16
    [date, ms] = extract_msecs(date, "99999")

  switch date.length
    #2010
    when 4
      y = parseInt(date)
      "#{y+1}-01-01#{tz}"

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

      "#{y2}-#{m2}-01#{tz}"

    #2010-02-03
    when 10 then "#{date}T23:59:59.99999#{tz}"

    #2010-02-03T10
    when 13 then "#{date}:59:59.99999#{tz}"

    #2010-03-05T23:50
    when 16 then "#{date}:59.99999#{tz}"

    #2010-03-05T23:50:30
    when 19 then "#{date}#{ms}#{tz}"
    else
      throw new Error("date.to_range: Don't know how to handle #{date}")

exports.to_range = (date)->
  return null unless date
  date = date.toString()
  return null if date.trim() == ''

  [date, tz] = extract_tz(date)
  hms = ''
  lms = ''
  if date.length > 16
    [date, hms] = extract_msecs(date, "99999")
    lms = hms.replace(/9/g, '0')

  switch date.length
    #2010
    when 4
      y = parseInt(date)
      "[#{y}-01-01#{tz},#{y+1}-01-01#{tz})"

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

      "[#{y1}-#{m1}-01#{tz},#{y2}-#{m2}-01#{tz})"

    #2010-02-03
    when 10 then "[#{date}#{tz},#{date}T23:59:59.99999#{tz}]"

    #2010-02-03T10
    when 13 then "[#{date}:00#{tz},#{date}:59:59.99999#{tz}]"

    #2010-03-05T23:50
    when 16 then "[#{date}:00.00000#{tz},#{date}:59.99999#{hms}#{tz}]"

    #2010-03-05T23:50:30
    when 19 then "[#{date}#{lms}#{tz},#{date}#{hms}#{tz}]"

    # Should we fail on wrong date?
    else
      throw new Error("date.to_range: Don't know how to handle #{date}")

exports.range = (start, ending)->
  if ending == 'infinity'
    "(#{to_lower_date(start)},infinity]"
  else if start == 'infinity'
    "[-infinity, #{to_upper_date(start)}]"
  else
    throw new Error('Unhandled case')

VALID_DATE_REGEX = /^-?[0-9]{4}(-(0[1-9]|1[0-2])(-(0[0-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)?$/
