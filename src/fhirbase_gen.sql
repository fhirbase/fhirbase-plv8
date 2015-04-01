proc _tpl(_tpl_ text, variadic _bindings_ varchar[]) RETURNS text
  --- replace {{var}} in template string
  --- EXAMPLE: _tpl('{{a}}={{b}}', 'a', 'A','b','B') => 'A=B'
  result text := _tpl_;
  BEGIN
    FOR i IN 1..(array_upper(_bindings_, 1)/2) LOOP
      result := replace(result, '{{' || _bindings_[i*2 - 1] || '}}', coalesce(_bindings_[i*2], ''));
    END LOOP;
    RETURN result;

proc! _eval(_str_ text) RETURNS text
  -- eval string
  BEGIN
    EXECUTE _str_;
    RETURN _str_;

proc! _eval_if(cond boolean, _str_ text) RETURNS text
  -- eval string
  BEGIN
    IF cond THEN
      EXECUTE _str_;
    END IF;
    RETURN _str_;
