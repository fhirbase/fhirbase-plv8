---  We use one table and one column to denormalize and simplify sorting
---  Here is implementation of ELEN for sorting numbers as text (i.e. in lexicographic order):
---  Efficient Lexicographic Encoding of Numbers
---  www.zanopha.com/docs/elen.pdf
---  Peter Seymour

func lexit(_str text) RETURNS text
  --- just for polymorphic interface
  select _str

func lex_reverse(_int text) RETURNS text
  SELECT string_agg(CASE
                    WHEN x = 'a' THEN '!'
                    WHEN x = '!' THEN 'a'
                    ELSE (9 - x::int)::text
                    END, '')
    FROM regexp_split_to_table(_int, '') x

-- private
func lex_prefix(_acc text, _int decimal) RETURNS text
  SELECT CASE
    WHEN char_length(_int::text) > 9 THEN
      this.lex_prefix(char_length(_int::text) || _acc,
                 char_length(_int::text))
    ELSE
      char_length(_int::text) || _acc
    END

--private
func _lexit_int(_int decimal) RETURNS text
  SELECT CASE
    WHEN _int = 0 THEN 'a0'
    WHEN _int < 0 THEN this.lex_reverse(this._lexit_int(-_int))
    ELSE
      (SELECT repeat('a', char_length(lex_prefix)) || lex_prefix || _int::text
        FROM this.lex_prefix('', _int))
    END

func lexit(_int bigint) RETURNS text
  --- encode bigint
  SELECT this._lexit_int(_int::decimal)


func lexit(_dec decimal) RETURNS text
  --- encode decimal
  SELECT CASE
    WHEN _dec = 0 THEN
      'a0'
    WHEN _dec > 0 AND _dec < 1 THEN
      'a0' || regexp_replace(_dec::text, '^0\.', '') || '!'
    WHEN _dec < 0 AND _dec > - 1 THEN
      this.lex_reverse(this.lexit(-_dec))
    WHEN  _dec > 1 THEN
      this._lexit_int(round(_dec)) || this.lexit(('0.' || split_part(_dec::text,'.',2))::decimal)
    WHEN _dec < -1 THEN
      this.lex_reverse(this._lexit_int(round(-_dec)) || this.lexit(('0.' || split_part(_dec::text,'.',2))::decimal))
    END

/* vim: ft=sql
*/
