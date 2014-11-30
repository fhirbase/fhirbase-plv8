--db:fhirb
--{{{
-- decode url-encoded string
CREATE OR REPLACE
FUNCTION _url_decode(input text) RETURNS text
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE
bin bytea = '';
byte text;
BEGIN
  FOR byte IN (select (regexp_matches(input, '(%..|.)', 'g'))[1]) LOOP
    IF length(byte) = 3 THEN
      bin = bin || decode(substring(byte, 2, 2), 'hex');
    ELSE
      bin = bin || byte::bytea;
    END IF;
  END LOOP;
  RETURN convert_from(bin, 'utf8');
END
$$;

CREATE OR REPLACE
FUNCTION _get_modifier(_key_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT nullif(split_part(_last(regexp_split_to_array(_key_,'\.')), ':',2), '');
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _get_key(_key_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT array_to_string(_butlast(a) || split_part(_last(a), ':', 1), '.')
from regexp_split_to_array(_key_, '\.') a;
$$ IMMUTABLE;


CREATE OR REPLACE
FUNCTION _get_operator(val text) RETURNS text
LANGUAGE sql AS $$
   SELECT
   CASE WHEN val ~ E'^(>=|<=|<|>|~).*' THEN
     regexp_replace(val, E'^(>=|<=|<|>|~).*','\1')
   ELSE
     NULL
   END
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _get_value(val text) RETURNS text
LANGUAGE sql AS $$
   SELECT regexp_replace(val, E'^(>|<|<=|>=|~)(.*)','\2')
$$ IMMUTABLE;

-- FHIR use operators & modifiers a:modifier=[operator]value
-- this concepts are orthogonal so
-- for the sake of simplicity we merge both them into only operator
-- get url encoded string and return relation (key, operator, value)
CREATE OR REPLACE
FUNCTION _query_string_to_params(_params_ text) RETURNS table(key text, operation text, value text)
LANGUAGE sql AS $$
  WITH
  initial AS (
    SELECT _url_decode(split_part(x,'=',1)) as key,
           _url_decode(split_part(x, '=', 2)) as val
      FROM regexp_split_to_table(_params_,'&') x
  ),
  with_op_mod AS (
    SELECT _get_key(key) as key,
           _get_modifier(key) as mod,
           _get_operator(val) as op,
           _get_value(val) as val
      FROM initial
  )
  SELECT key as param,
         COALESCE(op, mod, '=') as operation,
         val as value
  FROM with_op_mod
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION _build_query(_parts_ jsonb[]) RETURNS text
LANGUAGE sql AS $$
  SELECT 'ok'::text
$$ IMMUTABLE;


--}}}
