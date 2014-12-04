--db:fhirb
--{{{

-- copy/pasted url decode function
CREATE OR REPLACE FUNCTION url_decode(input text) RETURNS text
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

-- function extract modifier from last param in chain
-- Example: a.b.c:mod => mod
CREATE OR REPLACE
FUNCTION _get_modifier(_key_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT nullif(split_part(_last(regexp_split_to_array(_key_,'\.')), ':',2), '');
$$ IMMUTABLE;

-- function remove modifier from key and get last in chain x.y.z (i.e. z)
-- Example: a.b.c:mod => c
CREATE OR REPLACE
FUNCTION _get_key(_key_ text) RETURNS text
LANGUAGE sql AS $$
  SELECT array_to_string(_butlast(a) || split_part(_last(a), ':', 1), '.')
from regexp_split_to_array(_key_, '\.') a;
$$ IMMUTABLE;

-- this function accept parmas in query string form
-- and return jsonb array {param: '', op: '', value: ''}
-- fhir modifiers and operators treated as op
CREATE OR REPLACE
FUNCTION _parse_param(_params_ text) RETURNS jsonb
LANGUAGE sql AS $$

WITH initial AS (
  -- split params by & and then split by = return (key, val) relation
  SELECT url_decode(split_part(x,'=',1)) as key,
         url_decode(split_part(x, '=', 2)) as val
    FROM regexp_split_to_table(_params_,'&') x
), with_op_mod AS (
  SELECT  _get_key(key) as key, -- normalize key (remove modifiers)
          _get_modifier(key) as mod, -- extract modifier
          CASE WHEN val ~ E'^(>=|<=|<|>|~).*' THEN
            regexp_replace(val, E'^(>=|<=|<|>|~).*','\1') -- extract operator
          ELSE
            NULL
          END as op,
          regexp_replace(val, E'^(>|<|<=|>=|~)(.*)','\2') as val
    FROM  initial
)
-- build resulting array
SELECT json_agg(
  json_build_object(
    'param', key,
    'op',    COALESCE(op,mod,'='),
    'value', val))::jsonb
FROM with_op_mod;

$$ IMMUTABLE;
--}}}
