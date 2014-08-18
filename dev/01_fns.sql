--db:fhirb
--{{{

DROP FUNCTION IF EXISTS _tpl(_tpl_ text, variadic _bindings varchar[]);
CREATE
FUNCTION _tpl(_tpl_ text, variadic _bindings varchar[]) RETURNS text AS $$
--- replace {{var}} in template string
---  EXAMPLE:
---    _tpl('{{a}}={{b}}', 'a', 'A','b','B') => 'A=B'
DECLARE
  result text := _tpl_;
BEGIN
  FOR i IN 1..(array_upper(_bindings, 1)/2) LOOP
    result := replace(result, '{{' || _bindings[i*2 - 1] || '}}', coalesce(_bindings[i*2], ''));
  END LOOP;
  RETURN result;
END
$$ LANGUAGE plpgsql IMMUTABLE;


DROP FUNCTION IF EXISTS _eval(_str_ text);
CREATE
FUNCTION _eval(_str_ text) RETURNS text AS
--- eval _str_
$BODY$
BEGIN
  EXECUTE _str_;
  RETURN _str_;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;

DROP FUNCTION IF EXISTS _butlast(anyarray);
CREATE
FUNCTION _butlast(_ar_ anyarray) RETURNS anyarray
--- cut last element of array
language sql AS $$
  SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1];
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS _is_descedant(anyarray, anyarray);
CREATE
FUNCTION _is_descedant(_parent_ anyarray, _child_ anyarray) RETURNS boolean
--- test _parent_ is prefix of _child_
language sql AS $$
  SELECT _child_[array_lower(_parent_,1) : array_upper(_parent_,1)] = _parent_;
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS _subpath(anyarray, anyarray);
CREATE
FUNCTION _subpath(_parent_ anyarray, _child_ anyarray) RETURNS varchar[]
--- remove _parent_ elements from begining of _child_
language sql AS $$
  SELECT _child_[array_upper(_parent_,1) + 1 : array_upper(_child_,1)];
$$ IMMUTABLE;


DROP FUNCTION  IF EXISTS _rest(anyarray);
CREATE
FUNCTION _rest(_ar_ anyarray) RETURNS anyarray
--- return rest of array
language sql AS $$
  SELECT _ar_[2 : array_upper(_ar_,1)];
$$ IMMUTABLE;

DROP FUNCTION IF EXISTS _last(ar anyarray);
CREATE
FUNCTION _last(_ar_ anyarray) RETURNS anyelement
--- return last element of collection
language sql AS $$
  SELECT _ar_[array_length(_ar_,1)];
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION column_name(name varchar, type varchar) RETURNS varchar
--- just eat [x] from name
language sql AS $$
  SELECT replace(name, '[x]', '' || type);
$$  IMMUTABLE;

CREATE OR REPLACE
FUNCTION _is_array(_json jsonb) RETURNS boolean
language sql AS $$
  SELECT jsonb_typeof(_json) = 'array';
$$  IMMUTABLE;

CREATE OR REPLACE
FUNCTION _is_object(_json jsonb) RETURNS boolean
language sql AS $$
  SELECT jsonb_typeof(_json) = 'object';
$$  IMMUTABLE;

CREATE OR REPLACE
FUNCTION json_get_in(json jsonb, path varchar[]) RETURNS jsonb[]
--- get values by path (ignoring arrays)
LANGUAGE plpgsql AS $$
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
    IF _is_array(json) THEN
      FOR item IN SELECT jsonb_array_elements(json)
      LOOP
        acc := acc || item;
      END LOOP;
      RETURN acc;
    ELSE
      RETURN array[json];
    END IF;
  END IF;

  IF _is_array(json) THEN
    FOR item IN SELECT jsonb_array_elements(json)
    LOOP
      acc := acc || json_get_in(item,path);
    END LOOP;
    RETURN acc;
  ELSIF _is_object(json) THEN
    RETURN json_get_in(json->path[1], _rest(path));
  ELSE
    RETURN array[]::jsonb[];
  END IF;
END
$$;

CREATE OR REPLACE
FUNCTION jsonb_text_value(j jsonb) RETURNS varchar
LANGUAGE sql AS $$
  SELECT (json_build_object('x', j::json)->>'x')::varchar
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION json_array_to_str_array(_jsons jsonb[]) RETURNS varchar[]
LANGUAGE plpgsql AS $$
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

CREATE OR REPLACE
FUNCTION assert(_pred boolean, mess varchar) RETURNS varchar
--- simple test fn
LANGUAGE plpgsql AS $$
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

CREATE OR REPLACE
FUNCTION _debug(x anyelement) RETURNS anyelement
LANGUAGE plpgsql AS $$
BEGIN
  RAISE NOTICE 'DEBUG %', x;
  RETURN x;
END
$$;

CREATE OR REPLACE
FUNCTION assert_eq(expec anyelement, res anyelement, mess varchar) RETURNS varchar
LANGUAGE plpgsql AS $$
DECLARE
  item jsonb;
  acc varchar[] := array[]::varchar[];
BEGIN
  IF expec = res  OR (expec IS NULL AND res IS NULL) THEN
    RETURN 'OK ' || mess;
  ELSE
    RAISE EXCEPTION E'assert_eq % FAILED:\nEXPECTED: %\nACTUAL:   %', mess, expec, res;
    RETURN 'NOT OK';
  END IF;
END
$$;

CREATE OR REPLACE
FUNCTION assert_raise(exp varchar, str text, mess varchar) RETURNS varchar
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE str;
  EXCEPTION
    WHEN OTHERS THEN
      IF exp = SQLERRM THEN
        RETURN 'OK ' || mess;
    ELSE
      RAISE EXCEPTION E'assert_raise % FAILED:\nEXPECTED: %\nACTUAL:   %', mess, exp, SQLERRM;
      RETURN 'NOT OK';
    END IF;
  END;
  RAISE EXCEPTION E'assert_raise % FAILED:\nEXPECTED: %', mess, exp;
  RETURN 'NOT OK';
END
$$;

CREATE OR REPLACE
FUNCTION _fhir_unescape_param(_str text) RETURNS text
LANGUAGE sql AS $$
  SELECT regexp_replace(_str, $RE$\\([,$|])$RE$, E'\\1', 'g')
$$;

CREATE OR REPLACE
FUNCTION _fhir_spilt_to_table(_str text) RETURNS table (value text)
LANGUAGE sql AS $$
  SELECT _fhir_unescape_param(x)
   FROM regexp_split_to_table(regexp_replace(_str, $RE$([^\\]),$RE$, E'\\1,,,,,'), ',,,,,') x
$$;

--}}}
