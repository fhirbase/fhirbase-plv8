-- #import ./fhirbase_crud.sql
-- #import ./fhirbase_coll.sql
-- #import ./tests.sql


func _replace_references(_resource_ jsonb, _references_ jsonb[]) RETURNS jsonb
  SELECT
    CASE
    WHEN array_length(_references_, 1) > 0 THEN
     this._replace_references(
       replace(
         _resource_::text,
         ('"reference": "' || (_references_[1]->>'local') || '"'),
         '"reference": "' || (_references_[1]->>'created') || '"'
       )::jsonb,
       fhirbase_coll._rest(_references_))
   ELSE _resource_
   END

proc _url_to_crud_action(_url_ text, _method_ text) RETURNS text[]
  matches text[];
  BEGIN
    CASE _method_
    WHEN 'POST' THEN
      matches := regexp_matches(_url_, '^/?([^/]+)$');

      IF matches IS NULL THEN
        matches := regexp_matches(_url_, '^/?([^/]+)/_search$');

        IF matches IS NOT NULL THEN
           RETURN ARRAY['search', matches[1]];
        ELSE
          RAISE EXCEPTION 'Wrong URL for POST action: %', _url_;
        END IF;
      ELSE
        RETURN ARRAY['create', matches[1]];
      END IF;
    WHEN 'PUT', 'DELETE' THEN
      matches := regexp_matches(_url_, '^/?([^/]+)/([^/]+)$');

      IF matches IS NULL THEN
        RAISE EXCEPTION 'Wrong URL for PUT/DELETE action: %', _url_;
      END IF;

      IF _method_ = 'PUT' THEN
         RETURN ARRAY['update', matches[1], matches[2]];
      ELSE
        RETURN ARRAY['delete', matches[1], matches[2]];
      END IF;
    WHEN 'GET' THEN
      matches := regexp_matches(_url_, '^/?([^/]+)/([^/]+)$');
      IF matches IS NOT NULL THEN
        RETURN ARRAY['read', matches[1], matches[2]];
      END IF;

      matches := regexp_matches(_url_, '^/?([^/]+)/([^/]+)/_history/([^/]+)$');
      IF matches IS NOT NULL THEN
        RETURN ARRAY['vread', matches[1], matches[2], matches[3]];
      END IF;

      matches := regexp_matches(_url_, '^/?([^/]+)$');
      IF matches IS NOT NULL THEN
        RETURN ARRAY['search', matches[1]];
      ELSE
        RAISE EXCEPTION 'Wrong URL for GET action: %', _url_;
      END IF;
    END CASE;

proc! transaction(_cfg_ jsonb, _bundle_ jsonb) RETURNS jsonb
  --Update, create or delete a set of resources as a single transaction\nReturns bundle with entries
  _result_ jsonb[];
  _updated_entries_ jsonb[];
  i integer;

  _entry_ jsonb;
  _entry_with_replaced_ids_ jsonb;

  _method text;
  _process jsonb;
  _created_entries jsonb[];
  _ids_table jsonb[];

  BEGIN
    -- POST step
    _process := this._process_entries(_cfg_, _bundle_, 'POST');
    _created_entries := fhirbase_json.jsonb_to_array(_process->'entry');
    _ids_table := fhirbase_json.jsonb_to_array(_process->'ids');

    FOREACH _entry_ IN ARRAY _created_entries LOOP
      _entry_with_replaced_ids_ := this._replace_references(_entry_, _ids_table);

      IF _entry_with_replaced_ids_ != _entry_ THEN
        _result_ := _result_ || ARRAY[
          fhirbase_json.assoc(
            _entry_with_replaced_ids_,
            'resource',
            fhirbase_crud.update(_cfg_, (_entry_with_replaced_ids_->'resource'))
          )
        ];
      ELSE
        _result_ := _result_ || ARRAY[_entry_];
      END IF;
    END LOOP;

    -- Replace IDs in PUT entries in source Bundle
    _updated_entries_ = ARRAY[]::jsonb[];
    FOREACH _entry_ IN ARRAY fhirbase_json.jsonb_to_array(_bundle_->'entry') LOOP
      IF _entry_#>>'{transaction,method}' = 'PUT' THEN
        _updated_entries_ := _updated_entries_ || this._replace_references(_entry_, _ids_table);
      ELSE
        _updated_entries_ := _updated_entries_ || _entry_;
      END IF;
    END LOOP;

    _bundle_ := fhirbase_json.assoc(_bundle_, 'entry', array_to_json(_updated_entries_)::jsonb);

    FOREACH _method IN ARRAY '{PUT,DELETE,GET}'::text[] LOOP
      _result_ := _result_ || fhirbase_json.jsonb_to_array(this._process_entries(_cfg_, _bundle_, _method)->'entry');
    END loop;

    RETURN json_build_object(
       'resourceType', 'Bundle',
       'type', 'transaction-response',
       'entry', coalesce(_result_, '{}'::jsonb[])
    )::jsonb;

proc! _process_entries(_cfg_ jsonb, _bundle_ jsonb, _method_ text) RETURNS jsonb
  _entry_ jsonb[];
  _ids_ jsonb[];
  _item_ jsonb;
  _params text[];
  _tmp text;
  _local_id_ text;
  _created_id_ text;
  _resource_ jsonb;
  BEGIN
    FOR _item_ IN SELECT jsonb_array_elements(_bundle_->'entry')
    LOOP
      IF _item_#>>'{transaction,method}' = _method_ THEN
        _params := this._url_to_crud_action(_item_#>>'{transaction,url}', _item_#>>'{transaction,method}');
        IF _params[1] = 'create' THEN
          _local_id_ := _item_#>>'{resource,id}';
          _resource_ := fhirbase_crud.create(_cfg_, fhirbase_json.assoc(_item_->'resource', 'id', 'null'::jsonb));
          _created_id_ := (_resource_->>'resourceType') || '/' || (_resource_->>'id');

          IF _local_id_ IS NOT NULL THEN
             _ids_ := _ids_ || ARRAY[
               json_build_object('local', _local_id_, 'created', _created_id_)
             ]::jsonb[];
          END IF;

          _entry_ := _entry_ || ARRAY[
            fhirbase_json.assoc(_item_, 'resource', _resource_)
          ]::jsonb[];
        ELSIF _params[1] = 'update' THEN
          _entry_ := _entry_ || ARRAY[
            fhirbase_json.assoc(
              _item_,
              'resource',
              fhirbase_crud.update(_cfg_, _item_->'resource')
            )
          ]::jsonb[];
        ELSIF _params[1] = 'delete' THEN
          _entry_ := _entry_ || ARRAY[
            fhirbase_json.assoc(
              _item_,
              'resource',
              fhirbase_crud.delete(_cfg_, _params[2], _params[3])
            )
          ]::jsonb[];
        END IF;
      END IF;
    END LOOP;

    RETURN json_build_object(
       'ids', coalesce(_ids_, '{}'::jsonb[]),
       'entry', coalesce(_entry_, '{}'::jsonb[])
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
/*     LEFT JOIN resource r on r.logical_id = fhirbase_crud._extract_id(i.id) */
/*     WHERE i.deleted is null and r.logical_id is null */
/*   ), created_resources AS ( */
/*     SELECT */
/*       r.id as alternative, */
/*       fhirbase_crud.create(_cfg, r.content::jsonb)#>'{entry,0}' as entry */
/*     FROM create_resources r */
/*   ), reference AS ( */
/*     SELECT array( */
/*       SELECT json_build_object('alternative', r.alternative, 'id', r.entry->>'id') */
/*       FROM created_resources r) as refs */
/*   ), update_resources AS ( */
/*     SELECT i.* */
/*     FROM items i */
/*     LEFT JOIN resource r on r.logical_id = fhirbase_crud._extract_id(i.id) */
/*     WHERE i.deleted is null and r.logical_id is not null */
/*   ), updated_resources AS ( */
/*     SELECT */
/*       r.id as alternative, */
/*       fhirbase_crud.update(_cfg, this._replace_references(r.content::text, rf.refs)::jsonb) as entry */
/*     FROM create_resources r */
/*     JOIN created_resources cr on cr.alternative = r.id */
/*     JOIN reference rf on 1=1 */
/*     UNION ALL */
/*     SELECT */
/*       r.id as alternative, */
/*       fhirbase_crud.update(_cfg, this._replace_references(r.content::text, rf.refs)::jsonb) as entry */
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
/*         fhirbase_crud.delete(_cfg, rs.resource_type, r.id) as deleted */
/*       FROM delete_resources r */
/*       JOIN resource rs on rs.logical_id::text = fhirbase_crud._extract_id(r.id) */
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
/*   SELECT fhirbase_crud._build_bundle('Transaction results', count(r.*)::integer, COALESCE(json_agg(r.*), '[]'::json)) as json */
/*   FROM created r */
