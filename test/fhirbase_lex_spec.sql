-- #import ../src/tests.sql
-- #import ../src/fhirbase_lex.sql
SET search_path TO fhirbase_lex;

BEGIN;
lexit('abc') => 'abc'

-- TODO: add assertion using temporal table
SELECT x, lexit FROM (
  SELECT x::text, lexit(x)
    FROM unnest(
       ARRAY[1.11, 3.14, 0.1, 0.0001, -15.000123,  -0.000123 ,-0.99, -0.7, -0.1,  -0.11, -0.0001, -1.5, -3.14, -3.143, 3.143, 0.11, 0.7, 0.123e16, 0.123e-5, 0.3e19, 0.3e-20, 0.4e+43, -0.1133e33, -0.33e33, -0.16e16]) x
  UNION
  SELECT x::text, lexit(x)
    FROM unnest(
       ARRAY[11, 111, 88, 7, 0, 1234567890, -3, -11, -7, 9999999999, 111111111111111111, 1, 3]) x
) _
ORDER BY lexit;

ROLLBACK;
