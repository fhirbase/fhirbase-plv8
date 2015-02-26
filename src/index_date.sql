-- #import ./jsonbext.sql

func _date_parse_to_lower(_date text) RETURNS timestamptz
  -- index date
  SELECT CASE
  WHEN _date IS NULL THEN
    NULL
  WHEN _date ~ '^\d\d\d\d$' THEN    -- year
    (_date || '-01-01 00:00:00')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d$' THEN -- month
    (_date || '-01 00:00:00')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d$' THEN -- day
    (_date || ' 00:00:00')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d$' THEN -- hour
    (_date || ':00:00')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d$' THEN -- _dateute
    (_date || ':00')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d:\d\d(\.\d+)?((\+|\-)\d\d:\d\d)?$' THEN -- full date
    _date::timestamptz
  ELSE
    NULL
  END

func _date_parse_to_upper(_date text) RETURNS timestamptz
  SELECT CASE
  WHEN _date IS NULL THEN
    NULL
  WHEN _date ~ '^\d\d\d\d$' THEN    -- year
    (_date || '-01-01 00:00:00')::timestamptz + interval '1 year' - interval '1 second'
  WHEN _date ~ '^\d\d\d\d-\d\d$' THEN -- month
    (_date || '-01 00:00:00')::timestamptz + interval '1 month' - interval '1 second'
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d$' THEN -- day
    (_date || ' 23:59:59')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d$' THEN -- hour
    (_date || ':59:59')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d$' THEN -- _dateute
    (_date || ':59')::timestamptz
  WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d:\d\d(\.\d+)?((\+|\-)\d\d:\d\d)?$' THEN -- full date
    _date::timestamptz
  ELSE
    NULL
  END


func _datetime_to_tstzrange(_min text, _max text) RETURNS tstzrange
  SELECT CASE
  WHEN _min IS NULL THEN
    NULL
  WHEN _max is NULL AND _min IS NOT NULL THEN
     ('['|| this._date_parse_to_lower(_min) || ',' || ')')::tstzrange
  WHEN _min is NULL AND _max IS NOT NULL THEN
     ('(,' || this._date_parse_to_upper(_max) || ']' )::tstzrange
  WHEN _max is NOT NULL AND _min IS NOT NULL THEN
     ('['|| this._date_parse_to_lower(_min) || ',' || this._date_parse_to_upper(_max) || ']')::tstzrange
  ELSE
    NULL
  END


func index_as_date(content jsonb, path text[], type text) RETURNS tstzrange
  WITH dates AS (
    SELECT x
    FROM unnest(jsonbext.json_get_in(content, path)) x
    WHERE x is not null
  )
  SELECT
  CASE
  WHEN type = 'dateTime' OR type = 'date' OR type = 'instant' then
    (SELECT this._datetime_to_tstzrange(min(jsonbext.jsonb_primitive_to_text(x)),max(jsonbext.jsonb_primitive_to_text(x)::text)) FROM dates x)
  WHEN type = 'Period' then
    (SELECT this._datetime_to_tstzrange(min(x->>'start'), max(x->>'end')) FROM dates x)
  WHEN type = 'Schedule' then
    (
      --TODO: take duration into account
      SELECT this._datetime_to_tstzrange(min(y.mind::text),  max(y.maxd)) FROM (
        SELECT
        x#>>'{event,0,start}' as mind,
        COALESCE((x#>>'{event,0,end}'),(x#>>'{repeat,end}')) as maxd
        FROM dates x
      ) y
      WHERE y.mind IS NOT NULL
    )
  END
