--db:fhirb
--{{{
SELECT
count(
_eval(
_tpl(
$SQL$ CREATE INDEX {{idx}} ON {{tbl}} USING GIN (index_{{dtp}}_as_{{tp}}(content,'{{path}}')) $SQL$,
 'tbl', quote_ident(lower(resource_type))
,'tp', lower(search_type)
,'idx', replace(lower(resource_type || '_' || param_name || '_' || _last(path) || '_token_idx')::varchar,'-','_')
,'path', _rest(path)::varchar
,'dtp', CASE WHEN is_primitive THEN 'primitive' ELSE lower(type::varchar) END
)))
from fhir.resource_indexables
where search_type = 'token'
;
--}}}
