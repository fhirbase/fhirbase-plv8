-- #import ./fhirbase_json.sql
-- #import ./fhirbase_gen.sql
-- #import ./fhirbase_coll.sql
-- #import ./fhirbase_util.sql
-- #import ./fhirbase_params.sql
-- #import ./fhirbase_generate.sql

func _history_bundle(_cfg_ jsonb, _entries_ jsonb) RETURNS jsonb
  SELECT json_build_object(
    'type', 'history',
    'resourceType', 'Bundle',
    'entry', _entries_
  )::jsonb


func _extract_param(_params_ text, _key_ text) RETURNS text[]
  WITH params AS (
    -- split params by & and then split by = return (key, val) relation
    SELECT fhirbase_params.url_decode(split_part(x,'=',1)) as key,
           fhirbase_params.url_decode(split_part(x, '=', 2)) as val
      FROM regexp_split_to_table(_params_,'&') x
  )
  -- build resulting array
  SELECT array_agg(val)
  FROM params
  where key = _key_
  GROUP by key


proc history_sql(_cfg_ jsonb, _resource_type_ text, _id_ text, _parmas_ text) RETURNS text
  _count_ integer;
  _offset_ integer;
  _eid_ text;
  _since_ text;
  _since_sql_ text := '';
  BEGIN
    _eid_ := fhirbase_crud._extract_id(_id_);
    _count_ := COALESCE((this._extract_param(_parmas_, '_count'))[1]);
    _count_ := COALESCE(_count_, 100);

    _offset_ := COALESCE((this._extract_param(_parmas_, '_page'))[1]);
    _offset_ := COALESCE(_offset_, 0) * _count_;

    _since_ := this._extract_param(_parmas_,'_since');
    IF _since_ IS NOT NULL THEN
      _since_sql_ = format('WHERE updated >= %L', _since_);
    END IF;
    -- i'm not sure about efficency
    -- may be move limit and offset into deepest query
    RETURN format($SQL$
        SELECT json_agg(entry) FROM (
          SELECT json_build_object('resource', r.content)::jsonb as entry
          FROM (
            SELECT * FROM %I WHERE logical_id = %L
            UNION ALL
            SELECT * FROM %I WHERE logical_id = %L
          ) r
          %s
          ORDER BY r.updated desc
          LIMIT %s OFFSET %s
        ) _
    $SQL$,
      lower(_resource_type_),
      _eid_,
      (lower(_resource_type_) || '_history'),
      _eid_,
      _since_sql_,
      _count_,
      _offset_
     );

proc! history(_cfg_ jsonb, _resource_type_ text, _id_ text, _parmas_ text) RETURNS jsonb
  _result_ jsonb;
  BEGIN
    EXECUTE this.history_sql(_cfg_, _resource_type_, _id_, _parmas_) INTO _result_;
    RETURN this._history_bundle(_cfg_, _result_);

proc history_sql(_cfg_ jsonb, _resource_type_ text, _parmas_ text) RETURNS text
  _count_ integer;
  _offset_ integer;
  _since_ text;
  _since_sql_ text := '';
  BEGIN
    _count_ := COALESCE((this._extract_param(_parmas_, '_count'))[1]);
    _count_ := COALESCE(_count_, 100);

    _offset_ := COALESCE((this._extract_param(_parmas_, '_page'))[1]);
    _offset_ := COALESCE(_offset_, 0) * _count_;

    _since_ := this._extract_param(_parmas_,'_since');

    IF _since_ IS NOT NULL THEN
      _since_sql_ = format('WHERE updated >= %L', _since_);
    END IF;

    -- i'm not sure about efficency
    -- may be move limit and offset into deepest query
    RETURN format($SQL$
        SELECT json_agg(entry) FROM (
          SELECT json_build_object('resource', r.content)::jsonb as entry
          FROM (
            SELECT * FROM %I UNION ALL SELECT * FROM %I
          ) r
          %s -- since sql
          ORDER BY r.updated desc
          LIMIT %s OFFSET %s
        ) _
    $SQL$,
      lower(_resource_type_),
      (lower(_resource_type_) || '_history'),
      _since_sql_,
      _count_,
      _offset_
     );

proc! history(_cfg_ jsonb, _resource_type_ text, _parmas_ text) RETURNS jsonb
  _result_ jsonb;
  BEGIN
    EXECUTE this.history_sql(_cfg_, _resource_type_, _parmas_) INTO _result_;
    RETURN this._history_bundle(_cfg_, _result_);

proc history_sql(_cfg_ jsonb, _parmas_ text) RETURNS text
  _count_ integer;
  _offset_ integer;
  _since_ text;
  _since_sql_ text := '';
  BEGIN
    _count_ := COALESCE((this._extract_param(_parmas_, '_count'))[1]);
    _count_ := COALESCE(_count_, 100);

    _offset_ := COALESCE((this._extract_param(_parmas_, '_page'))[1]);
    _offset_ := COALESCE(_offset_, 0) * _count_;

    _since_ := this._extract_param(_parmas_,'_since');
    IF _since_ IS NOT NULL THEN
      _since_sql_ = format('WHERE updated >= %L', _since_);
    END IF;
    -- i'm not sure about efficency
    -- may be move limit and offset into deepest query
    RETURN format($SQL$
        SELECT json_agg(entry) FROM (
          SELECT json_build_object('resource', r.content)::jsonb as entry
          FROM ( SELECT * FROM resource UNION ALL SELECT * FROM resource_history) r
          %s
          ORDER BY r.updated desc
          LIMIT %s OFFSET %s
        ) _
    $SQL$, _since_sql_, _count_, _offset_);

proc! history(_cfg_ jsonb,  _parmas_ text) RETURNS jsonb
  _result_ jsonb;
  BEGIN
    EXECUTE this.history_sql(_cfg_, _parmas_) INTO _result_;
    RETURN this._history_bundle(_cfg_, _result_);
