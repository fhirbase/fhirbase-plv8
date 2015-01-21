-- #import ./vars.sql

create table this.results (
  file text,
  expected text,
  actual text,
  message text
);

proc! start() returns text
  BEGIN
    TRUNCATE this.results;
    RETURN 'start tests';

func! report() returns setof tests.results
  SELECT * FROM this.results

proc _debug(x anyelement) RETURNS anyelement
  BEGIN
    RAISE NOTICE 'DEBUG %', x;
    RETURN x;

proc! fail() RETURNS text
  _cnt_ integer;
  BEGIN
    SELECT count(*) INTO _cnt_ from this.results;
    IF _cnt_ > 0 THEN
      RAISE EXCEPTION '% tests failed', _cnt_;
    END IF;
    RETURN 'NOT OK';

proc! expect(_mess_ text, _loc_ text, _act_ anyelement, _expec_ anyelement) RETURNS text
  BEGIN
    IF _expec_ = _act_  OR (_expec_ IS NULL AND _act_ IS NULL) THEN
      RETURN 'OK';
    ELSE
      RAISE INFO E'\tFAILED: % \n\tEXPECTED:\t%\n\tACTUAL:  \t%\n\tFILE: %', _mess_, _expec_, _act_, _loc_;
      insert into this.results (file,expected,actual, message)
        values (_loc_, _expec_, _act_, _mess_);
      RETURN 'NOT OK';
    END IF;

proc! expect_raise(_err_ text, _loc_ text, _code_ text) RETURNS text
  BEGIN
    BEGIN
      EXECUTE _code_;
    EXCEPTION
      WHEN OTHERS THEN
        IF position(_err_ in SQLERRM) > 0 THEN
          RETURN 'OK; RAISE ' || _err_;
      ELSE
        RAISE INFO E'\tFAILED EXCEPTION: \n\tEXPECTED EXCEPTION: %\n\tACTUAL:   %\n\tFILE: %', _err_, SQLERRM, _loc_;
        RETURN 'NOT OK';
      END IF;
    END;
    RAISE INFO E'\tFAILED NO EXCEPTION: \n\tEXPECTED EXCEPTION: %\n\tBUT NO EXEPTION RAISED\n\tFILE: %', _err_, _loc_;
    RETURN 'NOT OK';
