-- #import ./crud.sql
-- #import ./coll.sql

func _replace_references(_resource_ text, _references_ json[]) RETURNS text
  SELECT
    CASE
    WHEN array_length(_references_, 1) > 0 THEN
     this._replace_references(
       replace(_resource_, _references_[1]->>'alternative', _references_[1]->>'id'),
       coll._rest(_references_))
   ELSE _resource_
   END


proc! transaction(_cfg_ jsonb, _bundle_ jsonb) RETURNS jsonb
  --Update, create or delete a set of resources as a single transaction\nReturns bundle with entries
  _entry_ jsonb[];
  _item_ jsonb;
  BEGIN
    FOR _item_ IN SELECT jsonb_array_elements(_bundle_->'entry')
    LOOP
      -- TODO: replace ids
      IF _item_->> 'status' = 'create' THEN
        _entry_ := _entry_ || ARRAY[
          jsonbext.assoc(
            _item_,
            'resource',
            crud.create(_cfg_, _item_->'resource')
          )
        ]::jsonb[];
      ELSIF _item_->> 'status' = 'update' THEN
        _entry_ := _entry_ || ARRAY[
          jsonbext.assoc(
            _item_,
            'resource',
            crud.update(_cfg_, _item_->'resource')
          )
        ]::jsonb[];
      ELSIF _item_->>'status' = 'delete' THEN
        _entry_ := _entry_ || ARRAY[
          jsonbext.assoc(
            _item_,
            'resource',
            crud.delete(_cfg_, _item_#>>'{deleted,type}', _item_#>>'{deleted,resourceId}')
          )
        ]::jsonb[];
      END IF;
    END LOOP;

    RETURN json_build_object(
       'type', 'transaction-response',
       'entry', _entry_
    )::jsonb;

/* func! fhir_transaction(_cfg jsonb, _bundle_ jsonb) RETURNS jsonb */
/*   --Update, create or delete a set of resources as a single transaction\nReturns bundle with entries */
/*   WITH entries AS ( */
/*     SELECT jsonb_array_elements(_bundle_->'entry') AS entry */
/*   ), items AS ( */
/*     SELECT */
/*       e.entry->>'id' AS id, */
/*       e.entry#>>'{link,0,href}' AS vid, */
/*       e.entry#>>'{content,resourceType}' AS resource_type, */
/*       e.entry->'content' AS content, */
/*       e.entry->'category' as category, */
/*       e.entry->>'deleted' AS deleted */
/*     FROM entries e */
/*   ), create_resources AS ( */
/*     SELECT i.* */
/*     FROM items i */
/*     LEFT JOIN resource r on r.logical_id = crud._extract_id(i.id) */
/*     WHERE i.deleted is null and r.logical_id is null */
/*   ), created_resources AS ( */
/*     SELECT */
/*       r.id as alternative, */
/*       crud.create(_cfg, r.content::jsonb)#>'{entry,0}' as entry */
/*     FROM create_resources r */
/*   ), reference AS ( */
/*     SELECT array( */
/*       SELECT json_build_object('alternative', r.alternative, 'id', r.entry->>'id') */
/*       FROM created_resources r) as refs */
/*   ), update_resources AS ( */
/*     SELECT i.* */
/*     FROM items i */
/*     LEFT JOIN resource r on r.logical_id = crud._extract_id(i.id) */
/*     WHERE i.deleted is null and r.logical_id is not null */
/*   ), updated_resources AS ( */
/*     SELECT */
/*       r.id as alternative, */
/*       crud.update(_cfg, this._replace_references(r.content::text, rf.refs)::jsonb) as entry */
/*     FROM create_resources r */
/*     JOIN created_resources cr on cr.alternative = r.id */
/*     JOIN reference rf on 1=1 */
/*     UNION ALL */
/*     SELECT */
/*       r.id as alternative, */
/*       crud.update(_cfg, this._replace_references(r.content::text, rf.refs)::jsonb) as entry */
/*     FROM update_resources r, reference rf */
/*   ), delete_resources AS ( */
/*     SELECT i.* */
/*     FROM items i */
/*     WHERE i.deleted is not null */
/*   ), deleted_resources AS ( */
/*     SELECT d.alternative, d.entry */
/*     FROM ( */
/*       SELECT */
/*         r.id as alternative, */
/*         ('{"id": "' || r.id || '"}')::jsonb as entry, */
/*         crud.delete(_cfg, rs.resource_type, r.id) as deleted */
/*       FROM delete_resources r */
/*       JOIN resource rs on rs.logical_id::text = crud._extract_id(r.id) */
/*     ) d */
/*   ), created AS ( */
/*     SELECT */
/*       r.entry->'content' as content, */
/*       r.entry->'updated' as updated, */
/*       r.entry->'published' as published, */
/*       r.entry->'id' as id, */
/*       r.entry->'category' as category, */
/*       r.entry->'link' as link, */
/*       r.alternative as alternative */
/*     FROM ( */
/*       SELECT * */
/*       FROM updated_resources */
/*       UNION ALL */
/*       SELECT * */
/*       FROM deleted_resources */
/*     ) r */
/*   ) */
/*   SELECT crud._build_bundle('Transaction results', count(r.*)::integer, COALESCE(json_agg(r.*), '[]'::json)) as json */
/*   FROM created r */
