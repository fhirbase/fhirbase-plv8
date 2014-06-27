--db:fhirb
--{{{
DROP FUNCTION IF EXISTS eval_template(_tpl_ text, variadic _bindings varchar[]);
CREATE FUNCTION
eval_template(_tpl_ text, variadic _bindings varchar[])
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
result text := _tpl_;
BEGIN
  FOR i IN 1..(array_upper(_bindings, 1)/2) LOOP
    result := replace(result, '{{' || _bindings[i*2 - 1] || '}}', coalesce(_bindings[i*2], ''));
  END LOOP;
  RETURN result;
END
$$;

DROP FUNCTION IF EXISTS eval_ddl(_str_ text);
CREATE FUNCTION eval_ddl(_str_ text)
RETURNS text AS
$BODY$
  begin
    EXECUTE _str_;
    RETURN _str_;
  end;
$BODY$
LANGUAGE plpgsql VOLATILE;

DROP FUNCTION IF EXISTS array_pop(_ar_ varchar[]);
CREATE FUNCTION array_pop(_ar_ varchar[])
RETURNS varchar[] language sql AS $$
  SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1];
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS is_subpath(_parent_ varchar[], _child_ varchar[]);
CREATE FUNCTION is_subpath(_parent_ varchar[], _child_ varchar[])
RETURNS boolean language sql AS $$
  SELECT _child_[array_lower(_parent_,1) : array_upper(_parent_,1)] = _parent_;
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS relative_path(_parent_ varchar[], _child_ varchar[]);
CREATE FUNCTION relative_path(_parent_ varchar[], _child_ varchar[])
RETURNS varchar[] language sql AS $$
    SELECT _child_[array_upper(_parent_,1) + 1 : array_upper(_child_,1)];
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS butlast(_ar_ varchar[]);
CREATE FUNCTION butlast(_ar_ varchar[])
  RETURNS varchar[] language sql AS $$
    SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1];
$$ IMMUTABLE;

-- remove last item from array
DROP FUNCTION IF EXISTS array_tail(varchar[]);
CREATE FUNCTION array_tail(_ar_ varchar[])
RETURNS varchar[] language sql AS $$
    SELECT _ar_[2 : array_upper(_ar_,1)];
$$ IMMUTABLE;


DROP FUNCTION  IF EXISTS rest(varchar[]);
CREATE FUNCTION rest(_ar_ varchar[])
RETURNS varchar[] language sql AS $$
    SELECT _ar_[2 : array_upper(_ar_,1)];
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS array_last(ar varchar[]);
CREATE FUNCTION array_last(_ar_ varchar[])
  RETURNS varchar language sql AS $$
    SELECT _ar_[array_length(_ar_,1)];
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION column_name(name varchar, type varchar)
  RETURNS varchar language sql AS $$
    SELECT replace(name, '[x]', '' || type);
$$  IMMUTABLE;

CREATE OR REPLACE FUNCTION
is_array(json jsonb)
  RETURNS boolean language sql AS $$
    SELECT
    CASE WHEN substring(json::text  from 1 for 1) = '['
      THEN true ELSE false
    END;
$$  IMMUTABLE;

--FIXME: use json_typeof
CREATE OR REPLACE FUNCTION
is_obj(json jsonb)
  RETURNS boolean language sql AS $$
    SELECT
    CASE WHEN substring(json::text  from 1 for 1) = '{'
      THEN true ELSE false
    END;
$$  IMMUTABLE;

CREATE or REPLACE
FUNCTION xattr(pth varchar, x xml) returns varchar
  as $$
  BEGIN
    return  unnest(xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']])) limit 1;
  END
$$ language plpgsql;

-- HACK: see http://joelonsql.com/2013/05/13/xml-madness/
-- problems with namespaces
CREATE OR REPLACE
FUNCTION xspath(pth varchar, x xml) returns xml[]
  as $$
  BEGIN
    return  xpath('/xml' || pth, xml('<xml xmlns:xs="xs">' || x || '</xml>'), ARRAY[ARRAY['xs','xs']]);
  END
$$ language plpgsql IMMUTABLE;

CREATE OR REPLACE
FUNCTION xsattr(pth varchar, x xml) returns varchar
  as $$
  BEGIN
    return  unnest(xspath( pth,x)) limit 1;
  END
$$ language plpgsql IMMUTABLE;


CREATE OR REPLACE
FUNCTION fpath(pth varchar, x xml) returns xml[]
  as $$
  BEGIN
    return xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']]);
  END
$$ language plpgsql IMMUTABLE;

create OR replace
function xarrattr(pth varchar, x xml) returns varchar[]
  as $$
  BEGIN
    RETURN array(select unnest(fpath(pth, x))::varchar);
  END
$$ language plpgsql;

CREATE OR REPLACE FUNCTION
tables_with_aliases(_tbls varchar[], _als varchar[])
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  res text = '';
  tbls varchar[] = array_discard_nulls(_tbls);
  als varchar[] = array_discard_nulls(_als);
  i integer;
BEGIN
  FOR i IN 1..array_upper(tbls, 1)
  LOOP
    res := res || quote_ident(tbls[i]) || ' ' || quote_ident(als[i]);

    IF i < array_upper(tbls, 1) AND length(res) > 0 THEN
      res := res || ', ';
    END IF;
  END LOOP;

  RETURN res;
END
$$;

CREATE OR REPLACE FUNCTION
keys_and_values_to_jsonb(keys varchar[], vals varchar[])
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  res text[];
  i integer;
BEGIN
  FOR i IN 1..array_upper(keys, 1)
  LOOP
    res := res || (to_json(keys[i])::varchar || ':' || to_json(vals[i])::varchar);
  END LOOP;

  RETURN ('{' || array_to_string(res, ', ') || '}')::jsonb;
END
$$;

CREATE OR REPLACE FUNCTION
get_in_path(json jsonb, path varchar[])
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
item jsonb;
acc jsonb[] := array[]::jsonb[];
BEGIN
  --RAISE NOTICE 'in with % and path %', json, path;
  IF json is NULL THEN
    --RAISE NOTICE 'ups';
    RETURN array[]::jsonb[];
  END IF;

  IF array_length(path, 1) IS NULL THEN
    -- expand array
    IF is_array(json) THEN
      FOR item IN
        SELECT jsonb_array_elements(json)
      LOOP
        acc := acc || item;
      END LOOP;
      RETURN acc;
    RETURN acc;
    ELSE
      RETURN array[json];
    END IF;
  END IF;

  IF is_array(json) THEN
    FOR item IN
      SELECT jsonb_array_elements(json)
    LOOP
      acc := acc || get_in_path(item,path);
    END LOOP;
    RETURN acc;
  ELSIF is_obj(json) THEN
    RETURN get_in_path(json->path[1], rest(path));
  ELSE
    RETURN array[]::jsonb[];
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION
jsonb_text_value(j jsonb)
RETURNS varchar LANGUAGE sql AS $$
  SELECT (json_build_object('x', j::json)->>'x')::varchar
$$;

CREATE OR REPLACE FUNCTION
array_discard_nulls(a varchar[])
RETURNS varchar[] LANGUAGE sql AS $$
SELECT array_agg("unnest") FROM unnest(a) WHERE "unnest" IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION
json_array_to_str_array(_jsons jsonb[])
RETURNS varchar[] LANGUAGE plpgsql AS $$
DECLARE
item jsonb;
acc varchar[] := array[]::varchar[];
BEGIN
  FOR item IN
    SELECT unnest(_jsons)
  LOOP
    acc := acc || (json_build_object('x', item)->>'x')::varchar;
  END LOOP;
  RETURN acc;
END
$$;

CREATE OR REPLACE FUNCTION
assert(_pred boolean, mess varchar)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE
item jsonb;
acc varchar[] := array[]::varchar[];
BEGIN
  IF _pred THEN
    RETURN 'OK ' || mess;
  ELSE
    RAISE EXCEPTION 'NOT OK %',  mess;
    RETURN 'not ok';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION
assert_eq(expec anyelement, res anyelement, mess varchar)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE
item jsonb;
acc varchar[] := array[]::varchar[];
BEGIN
  IF expec = res THEN
    RETURN 'OK ' || mess;
  ELSE
    RAISE EXCEPTION E'assert_eq % FAILED:\nEXPECTED: %\nACTUAL:   %', mess, expec, res;
    RETURN 'not ok';
  END IF;
END
$$;
--}}}
