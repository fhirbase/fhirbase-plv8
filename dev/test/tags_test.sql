--db:fhirb -e
--{{{

SELECT table_name FROM information_schema.tables
 WHERE table_schema='public'
   AND table_name = 'allergyintolerance_tag';

--}}}

