--db:fhirb
--{{{
CREATE OR REPLACE
FUNCTION _token_index_fn(dtype varchar, is_primitive boolean) RETURNS text
LANGUAGE sql AS $$
 SELECT  'index_' || CASE WHEN is_primitive THEN 'primitive' ELSE lower(dtype::varchar) END || '_as_token'
$$ IMMUTABLE;

/* SELECT _token_index_fn('UPS', false); */
/* SELECT _token_index_fn('UPS', true); */

--}}}
--{{{
-- index token
SELECT
count(
_eval(
_tpl(
$SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIN ({{idx_fn}}(content,'{{path}}')) $SQL$,
 'tbl', quote_ident(lower(resource_type))
,'tp', lower(search_type)
,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_token_idx')::varchar,'-','_')
,'path', _rest(path)::varchar
,'idx_fn', (SELECT _token_index_fn(type, is_primitive))
)))
from fhir.resource_indexables
where search_type = 'token'
;
--}}}
--{{{
-- index string
SELECT
count(
_eval(
_tpl(
$SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIN (index_as_string(content,'{{path}}'::text[]) gin_trgm_ops) $SQL$,
 'tbl', quote_ident(lower(resource_type))
,'tp', lower(search_type)
,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_token_idx')::varchar,'-','_')
,'path', _rest(path)::varchar
,'dtp', CASE WHEN is_primitive THEN 'primitive' ELSE lower(type::varchar) END
)))
from fhir.resource_indexables
where search_type = 'string'
;
--}}}

--{{{
-- index reference
SELECT
count(
_eval(
_tpl(
$SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIN (index_as_reference(content,'{{path}}')) $SQL$,
 'tbl', quote_ident(lower(resource_type))
,'tp', lower(search_type)
,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_token_idx')::varchar,'-','_')
,'path', _rest(path)::varchar
,'idx_fn', (SELECT _token_index_fn(type, is_primitive))
)))
from fhir.resource_indexables
where search_type = 'reference'
;
--}}}

--{{{
CREATE EXTENSION IF NOT EXISTS btree_gist ;
SELECT
count(_eval(
_tpl(
$SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIST (index_as_date(content,'{{path}}'::text[], '{{tp}}') range_ops) $SQL$,
 'tbl', quote_ident(lower(resource_type))
,'tp', type
,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_date')::varchar,'-','_')
,'path', _rest(path)::varchar
,'idx_fn', (SELECT _token_index_fn(type, is_primitive))
)
))
from fhir.resource_indexables
where search_type = 'date'
;
--}}}
