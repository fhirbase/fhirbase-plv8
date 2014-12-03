--db:fhirb
--{{{
DROP FUNCTION IF EXISTS string_idx(content, tp, path);
CREATE
FUNCTION string_idx(content jsonb, tp varchar, path varchar[]) RETURNS text
LANGUAGE SQL AS $$
  SELECT
  string_agg(part, ' ') FROM
  (
    WITH names AS (SELECT unnest as name FROM unnest(json_get_in(content::jsonb, path)))
    SELECT jsonb_array_elements_text( name->'given') as part FROM names
    UNION
    SELECT jsonb_array_elements_text( name->'family') as part FROM names
    UNION
    SELECT name->>'text' as part FROM names
  ) _
$$ IMMUTABLE;

SELECT string_idx(
'{"name":[{"given": ["ups", "dups"], "family":["fa","ba"], "text": "justtext"}]}'
, null,
 '{name}'
)
--}}}

SELECT
--*,
_tpl(
$SQL$ CREATE INDEX ON {{tbl}} GIN ({{tp}}_idx(content, '{{dtp}}', '{{path}}')) $SQL$,
 'tbl', lower(resource_type)
,'tp', lower(search_type)
,'path', path::varchar
,'dtp', type::varchar
)
from fhir.resource_indexables
where resource_type = 'Patient';
--}}}
