--db:fhirb
--{{{

CREATE OR REPLACE FUNCTION
index_period_to_date(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
BEGIN
  RETURN array[json_build_object(
  'param', _param_name,
  'start', _item->>'start',
  'end', _item->>'end'
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
        'start', _item->'event'->0->'start',
        'end', _item->'repeat'->'end'
      )::jsonb];
    ELSE
      RETURN array[]::jsonb[];
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION
index_datetime_or_instant_to_date(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  d timestamptz := _item::varchar::timestamptz;
BEGIN
  RETURN array[json_build_object(
  'param', _param_name,
  'start', d,
  'end', d
  )::jsonb];
END;
$$;

-- TODO: support variable date precision
CREATE OR REPLACE FUNCTION
index_date_to_date(_param_name varchar, _item jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  d date := _item::varchar::date;
  st timestamp := date_trunc('second', d);
  en timestamp := st + interval '24 hours';
BEGIN
  RETURN array[json_build_object(
  'param', _param_name,
  'start', st,
  'end', en
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
    attrs := get_in_path(rsrs, rest(prm.path));

    FOR item IN SELECT unnest(attrs)
    LOOP
      CASE
        WHEN prm.type = 'Period' THEN
          result := result || index_period_to_date(prm.param_name, item);
        WHEN prm.type = 'dateTime' or prm.type = 'instant' THEN
          result := result || index_datetime_or_instant_to_date(prm.param_name, item);
        WHEN prm.type = 'date' THEN
          result := result || index_date_to_date(prm.param_name, item);
        WHEN prm.type = 'Schedule' THEN
          result := result || index_schedule_to_date(prm.param_name, item);
        ELSE
          RAISE EXCEPTION 'unexpected index % : %', prm, attrs;
        END CASE;
    END LOOP;
  END LOOP;
  RETURN result;
END
$$;
--}}}
