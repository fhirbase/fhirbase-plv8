-- #import ./coll.sql
-- #import ./index_fns.sql

proc url_decode(input text) RETURNS text
  -- copy/pasted url decode function
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

func _get_modifier(_key_ text) RETURNS text
  -- function extract modifier from last param in chain
  -- Example: a.b.c:mod => mod
  SELECT nullif(split_part(coll._last(regexp_split_to_array(_key_,'\.')), ':',2), '');

func _get_key(_key_ text) RETURNS text
  -- function remove modifier from key and get last in chain x.y.z (i.e. z)
  -- Example: a.b.c:mod => c
  SELECT array_to_string(coll._butlast(a) || split_part(coll._last(a), ':', 1), '.')
    FROM regexp_split_to_array(_key_, '\.') a;

func _parse_param(_params_ text) RETURNS table (key text[], operator text, value text[])
  -- this function accept parmas in query string form
  -- and return jsonb array {param: '', op: '', value: ''}
  -- fhir modifiers and operators treated as op

  WITH initial AS (
    -- split params by & and then split by = return (key, val) relation
    SELECT searh_params.url_decode(split_part(x,'=',1)) as key,
           searh_params.url_decode(split_part(x, '=', 2)) as val
      FROM regexp_split_to_table(_params_,'&') x
  ), with_op_mod AS (
    SELECT  searh_params._get_key(key) as key, -- normalize key (remove modifiers)
            searh_params._get_modifier(key) as mod, -- extract modifier
            CASE WHEN val ~ E'^(>=|<=|<|>|~).*' THEN
              regexp_replace(val, E'^(>=|<=|<|>|~).*','\1') -- extract operator
            ELSE
              NULL
            END as op,
            regexp_replace(val, E'^(>|<|<=|>=|~)(.*)','\2') as val
      FROM  initial
  )
  -- build resulting array
  SELECT
    regexp_split_to_array(key, '\.') as key,
    COALESCE(op,mod,'=') as operator,
    regexp_split_to_array(index_fns._unaccent_string(val), ',') as value
  FROM with_op_mod;
