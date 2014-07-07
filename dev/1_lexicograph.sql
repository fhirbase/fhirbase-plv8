--db:fhirb
--{{{
---  We use one table and one column to denormalize and simplify sorting
---  Here is implementation of ELEN for sorting numbers as text (i.e. in lexicographic order):
---  Efficient Lexicographic Encoding of Numbers
---  www.zanopha.com/docs/elen.pdf
---  Peter Seymour

CREATE OR REPLACE
FUNCTION lexit(_str text) RETURNS text
--- just for polymorphic interface
LANGUAGE sql AS $$
  select _str;
$$;

-- private
CREATE OR REPLACE FUNCTION
lex_reverse(_int text) RETURNS text
LANGUAGE sql AS $$
  SELECT string_agg(CASE
                    WHEN regexp_split_to_table = 'a' THEN
                      '!'
                    WHEN regexp_split_to_table = '!' THEN
                      'a'
                    ELSE
                      (9 - regexp_split_to_table::int)::text
                    END, '')
    FROM regexp_split_to_table(_int, '')
$$;

-- private
CREATE OR REPLACE FUNCTION
lex_prefix(_acc text, _int decimal) RETURNS text
LANGUAGE sql AS $$
  SELECT CASE
    WHEN char_length(_int::text) > 9 THEN
      lex_prefix(char_length(_int::text) || _acc,
                 char_length(_int::text))
    ELSE
      char_length(_int::text) || _acc
    END;
$$ IMMUTABLE;

--private
CREATE OR REPLACE FUNCTION
_lexit_int(_int decimal) RETURNS text
LANGUAGE sql AS $$
  SELECT CASE
    WHEN _int = 0 THEN
      'a0'
    WHEN _int < 0 THEN
      lex_reverse(_lexit_int(-_int))
    ELSE
      (SELECT repeat('a', char_length(lex_prefix)) || lex_prefix || _int::text
        FROM lex_prefix('', _int))
    END;
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION lexit(_int bigint) RETURNS text
--- encode bigint
LANGUAGE sql AS $$
  SELECT _lexit_int(_int::decimal);
$$ IMMUTABLE;


CREATE OR REPLACE
FUNCTION lexit(_dec decimal) RETURNS text
--- encode decimal
LANGUAGE sql AS $$
  SELECT CASE
    WHEN _dec = 0 THEN
      'a0'
    WHEN _dec > 0 AND _dec < 1 THEN
      'a0' || regexp_replace(_dec::text, '^0\.', '') || '!'
    WHEN _dec < 0 AND _dec > - 1 THEN
      lex_reverse(lexit(-_dec))
    WHEN  _dec > 1 THEN
      _lexit_int(round(_dec)) || lexit(('0.' || split_part(_dec::text,'.',2))::decimal)
    WHEN _dec < -1 THEN
      lex_reverse(_lexit_int(round(-_dec)) || lexit(('0.' || split_part(_dec::text,'.',2))::decimal))
    END;
$$;
--}}}
