--db:fhirb
--{{{
CREATE OR REPLACE FUNCTION
admin_disk_usage_top(_limit integer)
RETURNS  table (relname text, size text)
LANGUAGE sql AS $$

  SELECT nspname || '.' || relname AS "relation",
  pg_size_pretty(pg_relation_size(C.oid)) AS "size"
  FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
  WHERE nspname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_relation_size(C.oid) DESC
  LIMIT _limit;

$$;
--}}}
