--db:fhirb
--{{{
CREATE OR REPLACE FUNCTION
_replace_references(_resource_ text, _references_ json[]) RETURNS text
LANGUAGE sql AS $$
  SELECT
    CASE
    WHEN array_length(_references_, 1) > 0 THEN
     _replace_references(
       replace(_resource_, _references_[1]->>'alternative', _references_[1]->>'id'),
       _rest(_references_))
   ELSE _resource_
   END;
$$;




CREATE OR REPLACE
FUNCTION fhir_transaction(_cfg jsonb, _bundle_ jsonb) RETURNS jsonb
LANGUAGE sql AS $$
  WITH entries AS (
    SELECT jsonb_array_elements(_bundle_->'entry') AS entry
  ), items AS (
    SELECT
      e.entry->>'id' AS id,
      e.entry#>>'{link,0,href}' AS vid,
      e.entry#>>'{content,resourceType}' AS resource_type,
      e.entry->'content' AS content,
      e.entry->'category' as category,
      e.entry->>'deleted' AS deleted
    FROM entries e
  ), create_resources AS (
    SELECT i.*
    FROM items i
    LEFT JOIN resource r on r.logical_id::text = _extract_id(i.id)
    WHERE i.deleted is null and r.logical_id is null
  ), created_resources AS (
    SELECT
      r.id as alternative,
      fhir_create(_cfg, r.resource_type, r.content::jsonb, r.category::jsonb)#>'{entry,0}' as entry
    FROM create_resources r
  ), reference AS (
    SELECT array(
      SELECT json_build_object('alternative', r.alternative, 'id', r.entry->>'id')
      FROM created_resources r) as refs
  ), update_resources AS (
    SELECT i.*
    FROM items i
    LEFT JOIN resource r on r.logical_id::text = _extract_id(i.id)
    WHERE i.deleted is null and r.logical_id is not null
  ), updated_resources AS (
    SELECT
      r.id as alternative,
      fhir_update(_cfg, r.resource_type, cr.entry->>'id',
        cr.entry#>>'{link,0,href}',
        _replace_references(r.content::text, rf.refs)::jsonb, '[]'::jsonb)#>'{entry,0}' as entry
    FROM create_resources r
    JOIN created_resources cr on cr.alternative = r.id
    JOIN reference rf on 1=1
    UNION ALL
    SELECT
      r.id as alternative,
      fhir_update(_cfg, r.resource_type, r.id, r.vid, _replace_references(r.content::text, rf.refs)::jsonb, r.category::jsonb)#>'{entry,0}' as entry
    FROM update_resources r, reference rf
  ), delete_resources AS (
    SELECT i.*
    FROM items i
    WHERE i.deleted is not null
  ), deleted_resources AS (
    SELECT d.alternative, d.entry
    FROM (
      SELECT
        r.id as alternative,
        ('{"id": "' || r.id || '"}')::jsonb as entry,
        fhir_delete(_cfg, rs.resource_type, r.id) as deleted
      FROM delete_resources r
      JOIN resource rs on rs.logical_id::text = _extract_id(r.id)
    ) d
  ), created AS (
    SELECT
      r.entry->'content' as content,
      r.entry->'updated' as updated,
      r.entry->'published' as published,
      r.entry->'id' as id,
      r.entry->'category' as category,
      r.entry->'link' as link,
      r.alternative as alternative
    FROM (
      SELECT *
      FROM updated_resources
      UNION ALL
      SELECT *
      FROM deleted_resources
    ) r
  )
  SELECT _build_bundle('Transaction results', count(r.*)::integer, COALESCE(json_agg(r.*), '[]'::json)) as json
  FROM created r;
$$;
COMMENT ON FUNCTION fhir_transaction(_cfg jsonb, _bundle_ jsonb)
IS 'Update, create or delete a set of resources as a single transaction\nReturns bundle with entries';
--}}}
