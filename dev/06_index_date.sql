--db:fhirb
--{{{

CREATE OR REPLACE FUNCTION
convert_fhir_date_to_pgrange(d varchar)
RETURNS tstzrange LANGUAGE plpgsql AS $$
DECLARE
  d1 timestamptz;
BEGIN
  CASE
  WHEN d ~ '^\d\d\d\d$' THEN    -- year
  RETURN tstzrange((d || '-01-01 00:00:00')::timestamptz, (d || '-12-31 23:59:59')::timestamptz);
  WHEN d ~ '^\d\d\d\d-\d\d$' THEN -- month
    d1 := (d || '-01 00:00:00')::timestamptz;
    RETURN tstzrange(d1, d1 + interval '1 month' - interval '1 second');
  WHEN d ~ '^\d\d\d\d-\d\d-\d\d$' THEN -- day
    d1 := (d || ' 00:00:00')::timestamptz;
    RETURN tstzrange(d1, d1 + interval '23 hours 59 minutes 59 seconds');
  WHEN d ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d$' THEN -- hour
    d1 := (d || ':00:00')::timestamptz;
    RETURN tstzrange(d1, d1 + interval '59 minutes 59 seconds');
  WHEN d ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d$' THEN -- minute
    d1 := (d || ':00')::timestamptz;
    RETURN tstzrange(d1, d1 + interval '59 seconds');
  WHEN d ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d:\d\d(\.\d+)?((\+|\-)\d\d:\d\d)?$' THEN -- full date
    RETURN ('[' || d || ',' || d || ']')::tstzrange;
  ELSE
    RAISE EXCEPTION 'unknown date format: %', d;
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION
index_period_to_date(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
BEGIN
  RETURN array[json_build_object(
  'param', _param_name,
  'start', lower(convert_fhir_date_to_pgrange(_item->>'start')),
  'end', upper(convert_fhir_date_to_pgrange(_item->>'end'))
  )::jsonb];
END;
$$;

CREATE OR REPLACE FUNCTION
index_schedule_to_date(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  res jsonb[];
BEGIN
  IF (_item->'repeat') IS NULL THEN
    SELECT array_agg(json_build_object(
      'param', _param_name,
      'start', ev->>'start',
      'end', ev->>'end'
      )::jsonb)
    FROM json_array_elements((_item->'event')::json) AS ev
    INTO res;
    RETURN res;
  ELSE
    IF (_item->'event'->0->'start') IS NOT NULL OR (_item->'repeat'->'end') IS NOT NULL THEN
      RETURN array[json_build_object(
        'param', _param_name,
        'start', _item->'event'->0->>'start',
        'end', _item->'repeat'->>'end'
      )::jsonb];
    ELSE
      RETURN array[]::jsonb[];
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION
index_date_or_datetime_or_instant_to_date(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  d tstzrange := convert_fhir_date_to_pgrange(jsonb_text_value(_item));
BEGIN
  RETURN array[json_build_object(
  'param', _param_name,
  'start', lower(d),
  'end', upper(d)
  )::jsonb];
END;
$$;

CREATE OR REPLACE FUNCTION
index_date_resource(rsrs jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  prm fhir.resource_indexables%rowtype;
  attrs jsonb[];
  item jsonb;
  result jsonb[] := array[]::jsonb[];
BEGIN
  FOR prm IN
    SELECT * FROM fhir.resource_indexables
    WHERE resource_type = rsrs->>'resourceType'
    AND search_type = 'date'
  LOOP
    attrs := json_get_in(rsrs, _rest(prm.path));

    FOR item IN SELECT unnest(attrs)
    LOOP
      CASE
        WHEN prm.type = 'Period' THEN
          result := result || index_period_to_date(prm.param_name, item);
        WHEN prm.type = 'dateTime' OR prm.type = 'instant' OR prm.type = 'date' THEN
          result := result || index_date_or_datetime_or_instant_to_date(prm.param_name, item);
        WHEN prm.type = 'Schedule' THEN
          result := result || index_schedule_to_date(prm.param_name, item);
        ELSE
          RAISE EXCEPTION 'unexpected date index % : %', prm, attrs;
        END CASE;
    END LOOP;
  END LOOP;
  RETURN result;
END
$$;

CREATE OR REPLACE FUNCTION
_search_date_expression(_table varchar, _param varchar, _type varchar, _op varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT
  CASE WHEN _op = '=' THEN
    quote_literal(val) || '::tstzrange @> tstzrange(' || quote_ident(_table) || '."start", ' || quote_ident(_table) || '."end")'
  WHEN _op = '>' THEN
    'tstzrange(' || quote_ident(_table) || '."start", ' || quote_ident(_table) || '."end") && ' || 'tstzrange(' || quote_literal(upper(val)) || ', NULL)'
  WHEN _op = '<' THEN
    'tstzrange(' || quote_ident(_table) || '."start", ' || quote_ident(_table) || '."end") && ' || 'tstzrange(NULL, ' || quote_literal(lower(val)) || ')'
  ELSE
  '1'
  END
  FROM (SELECT convert_fhir_date_to_pgrange(_value) AS val) _;
$$;
--}}}
