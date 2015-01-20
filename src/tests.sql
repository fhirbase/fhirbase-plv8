-- #import ./vars.sql

proc assert(_pred boolean, mess varchar) RETURNS varchar
  --- simple test fn
  item jsonb;
  acc varchar[] := array[]::varchar[];
  BEGIN
    IF _pred THEN
      RETURN 'OK ' || mess;
    ELSE
      RAISE EXCEPTION 'NOT OK %',  mess;
      RETURN 'not ok';
    END IF;

proc _debug(x anyelement) RETURNS anyelement
  BEGIN
    RAISE NOTICE 'DEBUG %', x;
    RETURN x;

proc assert_eq(expec anyelement, res anyelement, mess varchar) RETURNS varchar
  item jsonb;
  acc varchar[] := array[]::varchar[];
  BEGIN
    IF expec = res  OR (expec IS NULL AND res IS NULL) THEN
      RETURN 'OK ' || mess;
    ELSE
      RAISE EXCEPTION E'assert_eq % FAILED:\nEXPECTED: %\nACTUAL:   %', mess, expec, res;
      RETURN 'NOT OK';
    END IF;

proc expect(mess varchar, loc varchar, res anyelement, expec anyelement) RETURNS varchar
  item jsonb;
  acc varchar[] := array[]::varchar[];
  BEGIN
    IF expec = res  OR (expec IS NULL AND res IS NULL) THEN
      RETURN 'OK';
    ELSE
      RAISE INFO E'\tFAILED: % \n\tEXPECTED:\t%\n\tACTUAL:  \t%\n\tFILE: %', mess, expec, res, loc;
      RETURN 'NOT OK';
    END IF;

proc expect_raise(_err_ text, _loc_ text, _code_ varchar) RETURNS varchar
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

