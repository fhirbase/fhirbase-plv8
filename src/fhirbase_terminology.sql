-- #import ./fhirbase_json.sql
-- #import ./fhirbase_crud.sql

proc include_filter(_system_ text, _version_ text, filters jsonb) RETURNS text
  BEGIN
    RETURN '{}'::jsonb;

func _expand_define(_vs_ jsonb, _filter_ text) RETURNS jsonb
  select
    fhirbase_json.assoc(
      _vs_,
      'expansion', json_build_object(
        'identifier', '???',
        'timestamp', '???',
        'contains', coalesce(json_agg(y.*), '[]')
      )::jsonb
    ) from (
      select
        _vs_#>>'{define,system}' as system
        , x->>'code' as code
        , x->>'display' as display
        , x->>'definition' as definition
      from jsonb_array_elements(_vs_#>'{define,concept}') as x
      WHERE  _filter_ = ''
        OR (x->>'display' ilike '%' || _filter_ || '%' OR  x->>'code'    ilike '%' || _filter_ || '%')
  ) y

proc expand(_vs_id_ text, _filter_ text) RETURNS jsonb
  _vs_ jsonb;
  BEGIN
    SELECT content INTO _vs_
      FROM valueset where logical_id = _vs_id_;

    IF (_vs_->>'define') is not null AND (_vs_->>'compose') is null THEN
      RETURN this._expand_define(_vs_, _filter_);
    ELSE
      RETURN '{"resourceType": "OperationOutcome", "message": "Not implemented"}'::jsonb;
    END IF;

jsfn test(x json) RETURNS json
  var x = {a: 1};
  return x;
