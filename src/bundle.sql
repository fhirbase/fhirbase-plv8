
func build() returns jsonb
  SELECT '{}'::jsonb

func _build_bundle(_title_ text, _total_ integer, _entry_ json) RETURNS jsonb
  SELECT  json_build_object(
    'title', _title_,
    'id', gen_random_uuid()::text,
    'resourceType', 'Bundle',
    'totalResults', _total_,
    'updated', now(),
    'entry', _entry_
  )::jsonb

/* func _build_url(_cfg_ jsonb, VARIADIC path text[]) RETURNS text */
/*   SELECT _cfg_->>'base' || '/' || (SELECT string_agg(x, '/') FROM unnest(path) x) */

/* func _build_link(_cfg_ jsonb, _type_ text, _id_ text, _vid_  text) RETURNS jsonb */
/*   SELECT json_build_object( */
/*     'rel', 'self', */
/*     'href', this._build_url(_cfg_, _type_, _id_::text, '_history', _vid_::text) */
/*   )::jsonb */

/* func _build_id(_cfg_ jsonb, _type_ text, _id_ text) RETURNS text */
/*   SELECT this._build_url(_cfg_, _type_, _id_::text) */

/* func _extract_id(_id_ text) RETURNS text */
/*   SELECT coll._last(regexp_split_to_array((regexp_split_to_array(_id_, '/_history/')::text[])[1], '/')); */

/* func _extract_vid(_id_ text) RETURNS text */
/*   -- TODO: raise if not valid url */
/*   SELECT coll._last(regexp_split_to_array(_id_, '/_history/')); */

/* func _build_bundle(_title_ text, _total_ integer, _entry_ json) RETURNS jsonb */
/*   SELECT  json_build_object( */
/*     'title', _title_, */
/*     'id', gen_random_uuid()::text, */
/*     'resourceType', 'Bundle', */
/*     'totalResults', _total_, */
/*     'updated', now(), */
/*     'entry', _entry_ */
/*   )::jsonb */

/* -- TODO: move out of crud to util */
/* func _build_entry(_cfg_ jsonb, _line "resource") RETURNS json */
/*   SELECT row_to_json(x.*) FROM ( */
/*     SELECT _line.content, */
/*            _line.updated, */
/*            _line.published AS published, */
/*            this._build_id(_cfg_, _line.resource_type, _line.logical_id) AS id, */
/*            _line.category, */
/*            json_build_array( */
/*              this._build_link(_cfg_, _line.resource_type, _line.logical_id, _line.version_id)::json */
/*            )::jsonb   AS link */
/*   ) x */
