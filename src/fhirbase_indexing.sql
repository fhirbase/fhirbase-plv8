-- #import ./fhirbase_coll.sql
-- #import ./fhirbase_gen.sql
-- #import ./fhirbase_idx_fns.sql
-- #import ./fhirbase_date_idx.sql

CREATE EXTENSION IF NOT EXISTS btree_gist ;

func _token_index_fn(dtype text, is_primitive boolean) RETURNS text
  SELECT  'fhirbase_idx_fns.index_'
  || CASE WHEN is_primitive THEN 'primitive'
          WHEN dtype IS NOT NULL THEN lower(dtype::text)
          ELSE 'ups' END
  || '_as_token'

func _index_name(_meta searchparameter) RETURNS text
  SELECT replace('fb_' || lower(_meta.base || '_' || _meta.name || '_' ||  fhirbase_coll._last(_meta.path) || '_' || _meta.search_type || '_idx')::text,'-','_')

func _index_token_exp(_meta searchparameter) RETURNS text
  SELECT
   format(
    'CREATE INDEX %I ON %I USING GIN (%s(content,%L))'
    , this._index_name(_meta)
    , lower(_meta.base)
    , this._token_index_fn(_meta.type, _meta.is_primitive)
    , fhirbase_coll._rest(_meta.path)::text
   )

func _index_reference_exp(_meta searchparameter) RETURNS text
  SELECT
    format(
      'CREATE INDEX %I ON %I USING GIN (fhirbase_idx_fns.index_as_reference(content,%L))'
      ,this._index_name(_meta)
      ,lower(_meta.base)
      ,fhirbase_coll._rest(_meta.path)::text
    )

func _index_string_exp(_meta searchparameter) RETURNS text
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIN (fhirbase_idx_fns.index_as_string(content,%L::text[]) gin_trgm_ops)'
      ,this._index_name(_meta)
      ,lower(_meta.base)
      ,fhirbase_coll._rest(_meta.path)::text
    )

func _index_date_exp(_meta searchparameter) RETURNS text
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIST (fhirbase_date_idx.index_as_date(content,%L::text[], %L) range_ops)'
      ,this._index_name(_meta)
      ,lower(_meta.base)
      ,fhirbase_coll._rest(_meta.path)::text
      ,_meta.type
    )

func _index_search_param_exp(x searchparameter) RETURNS text
 SELECT
 CASE
   WHEN x.search_type = 'token' THEN this._index_token_exp(x)
   WHEN x.search_type = 'reference' THEN this._index_reference_exp(x)
   WHEN x.search_type = 'string' THEN this._index_string_exp(x)
   WHEN x.search_type = 'date' THEN this._index_date_exp(x)
   ELSE ''
 END

func _is_indexed(_meta searchparameter) RETURNS boolean
  SELECT coalesce((
   SELECT true FROM pg_indexes
     WHERE indexname = this._index_name(_meta)), false)

func _is_indexed(_resource_type_ text, _name_ text) RETURNS boolean
  SELECT this._is_indexed(ROW(x.*))
  FROM searchparameter x
  WHERE base = _resource_type_
  AND  name = _name_
  LIMIT 1

func index_search_param(_resource_type text, _name_ text) RETURNS text
  SELECT count(
      fhirbase_gen._eval_if(
        not this._is_indexed(ROW(x.*)),
        this._index_search_param_exp(ROW(x.*))
      )
    )::text
  FROM searchparameter x
  WHERE base = _resource_type
  AND  name = _name_
  AND path is not null
  AND type is not null

func index_resource(_resource text) RETURNS table (idx text)
  SELECT
  fhirbase_gen._eval_if(
    not this._is_indexed(ROW(x.*)),
    this._index_search_param_exp(ROW(x.*))
  )
  from searchparameter x
  where search_type IN ('token', 'reference', 'string', 'date')
  and base = _resource
  and path is not null

func index_all_resources() RETURNS table (idx text)
  SELECT
    fhirbase_gen._eval_if(
      not this._is_indexed(ROW(x.*)),
      this._index_search_param_exp(ROW(x.*))
    )
  from searchparameter x
  join structuredefinition p ON p.name = x.base AND p.installed = true
  where search_type IN ('token', 'reference', 'string', 'date')
  and x.type is not null

-- drop functions

func drop_index_search_param_exp(_meta searchparameter) RETURNS text
  SELECT format('DROP INDEX IF EXISTS %I',this._index_name(_meta))

func drop_index_search_param(_resource_type text, _name_ text) RETURNS bigint
  SELECT count(fhirbase_gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  FROM searchparameter x
  WHERE base = _resource_type
  AND  name = _name_
  and path is not null
  and type is not null

func drop_resource_indexes(_resource text) RETURNS bigint
  SELECT count(fhirbase_gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  from searchparameter x
  where base = _resource
  and path is not null
  and type is not null

func drop_all_resource_indexes() RETURNS bigint
  SELECT count(fhirbase_gen._eval(this.drop_index_search_param_exp(ROW(x.*))))
  FROM searchparameter x
  WHERE x.path is not null
    and x.type is not null

-- maintaince functions
-- from https://wiki.postgresql.org/wiki/Index_Maintenance
func indexes_summary() RETURNS table (tablename text, rows_in_bytes text, num_rows real, number_of_indexes bigint, "unique" text, single_column bigint, multi_column bigint)
  SELECT
      pg_class.relname::text,
      pg_size_pretty(pg_class.reltuples::bigint) AS rows_in_bytes,
      pg_class.reltuples AS num_rows,
      count(indexname) AS number_of_indexes,
      CASE WHEN x.is_unique = 1 THEN 'Y'
         ELSE 'N'
      END AS UNIQUE,
      SUM(case WHEN number_of_columns = 1 THEN 1
                ELSE 0
              END) AS single_column,
      SUM(case WHEN number_of_columns IS NULL THEN 0
               WHEN number_of_columns = 1 THEN 0
               ELSE 1
             END) AS multi_column
  FROM pg_namespace
  LEFT OUTER JOIN pg_class ON pg_namespace.oid = pg_class.relnamespace
  LEFT OUTER JOIN
         (SELECT indrelid,
             max(CAST(indisunique AS integer)) AS is_unique
         FROM pg_index
         GROUP BY indrelid) x
         ON pg_class.oid = x.indrelid
  LEFT OUTER JOIN
      ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns FROM pg_index x
             JOIN pg_class c ON c.oid = x.indrelid
             JOIN pg_class ipg ON ipg.oid = x.indexrelid  )
      AS foo
      ON pg_class.relname = foo.ctablename
  WHERE
       pg_namespace.nspname='public'
  AND  pg_class.relkind = 'r'
  GROUP BY pg_class.relname, pg_class.reltuples, x.is_unique
  ORDER BY 2;

func indexes_usage() RETURNS table (tablename text, indexname text, num_rows real, table_size text, index_size text, "unique" text, number_of_scans bigint, tuples_read bigint, tuples_fetched bigint)
  SELECT
      t.tablename::text,
      indexname::text,
      c.reltuples AS num_rows,
      pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
      pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
      CASE WHEN indisunique THEN 'Y'
         ELSE 'N'
      END AS UNIQUE,
      idx_scan AS number_of_scans,
      idx_tup_read AS tuples_read,
      idx_tup_fetch AS tuples_fetched
  FROM pg_tables t
  LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
  LEFT OUTER JOIN
      ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns, idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
             JOIN pg_class c ON c.oid = x.indrelid
             JOIN pg_class ipg ON ipg.oid = x.indexrelid
             JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid )
      AS foo
      ON t.tablename = foo.ctablename
  WHERE t.schemaname='public'
  ORDER BY 1,2;

func duplicate_indexes() returns table("size" text, idx1 text,idx2 text,idx3 text,idx4  text)
  SELECT
    pg_size_pretty(sum(pg_relation_size(idx))::bigint) AS size,
    (array_agg(idx))[1]::text AS idx1,
    (array_agg(idx))[2]::text AS idx2,
    (array_agg(idx))[3]::text AS idx3,
    (array_agg(idx))[4]::text AS idx4
  FROM (
    SELECT indexrelid::regclass AS idx, (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
      coalesce(indexprs::text,'')||E'\n' || coalesce(indpred::text,'')) AS KEY
    FROM pg_index) sub
  GROUP BY KEY HAVING count(*)>1
  ORDER BY sum(pg_relation_size(idx)) DESC;
