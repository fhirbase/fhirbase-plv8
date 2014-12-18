--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: fhir; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA fhir;


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: query_param; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE query_param AS (
	parent_resource text,
	link_path text[],
	resource_type text,
	chain text[],
	search_type text,
	is_primitive boolean,
	type text,
	field_path text[],
	key text,
	operator text,
	value text[]
);


--
-- Name: _build_bundle(text, integer, json); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _build_bundle(_title_ text, _total_ integer, _entry_ json) RETURNS jsonb
    LANGUAGE sql
    AS $$
  SELECT  json_build_object(
    'title', _title_,
    'id', gen_random_uuid(),
    'resourceType', 'Bundle',
    'totalResults', _total_,
    'updated', now(),
    'entry', _entry_
  )::jsonb

$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: resource; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE resource (
    version_id uuid,
    logical_id uuid,
    resource_type character varying,
    updated timestamp with time zone,
    published timestamp with time zone,
    category jsonb,
    content jsonb
);


--
-- Name: _build_entry(jsonb, resource); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _build_entry(_cfg jsonb, _line resource) RETURNS json
    LANGUAGE sql
    AS $$
  SELECT row_to_json(x.*) FROM (
    SELECT _line.content,
           _line.updated,
           _line.published AS published,
           _build_id(_cfg, _line.resource_type, _line.logical_id) AS id,
           _line.category,
           json_build_array(
             _build_link(_cfg, _line.resource_type, _line.logical_id, _line.version_id)::json
           )::jsonb   AS link
  ) x
$$;


--
-- Name: _build_id(jsonb, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _build_id(_cfg jsonb, _type_ text, _id_ uuid) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT _build_url(_cfg, _type_, _id_::text)
$$;


--
-- Name: _build_link(jsonb, text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _build_link(_cfg jsonb, _type_ text, _id_ uuid, _vid_ uuid) RETURNS jsonb
    LANGUAGE sql
    AS $$
  SELECT json_build_object(
    'rel', 'self',
    'href', _build_url(_cfg, _type_, _id_::text, '_history', _vid_::text)
  )::jsonb
$$;


--
-- Name: _build_url(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _build_url(_cfg jsonb, VARIADIC path text[]) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT _cfg->>'base' || '/' || (SELECT string_agg(x, '/') FROM unnest(path) x)
$$;


--
-- Name: _butlast(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _butlast(_ar_ anyarray) RETURNS anyarray
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1];
$$;


--
-- Name: _date_parse_to_lower(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _date_parse_to_lower(_date text) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT CASE
WHEN _date IS NULL THEN
  NULL
WHEN _date ~ '^\d\d\d\d$' THEN    -- year
  (_date || '-01-01 00:00:00')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d$' THEN -- month
  (_date || '-01 00:00:00')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d$' THEN -- day
  (_date || ' 00:00:00')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d$' THEN -- hour
  (_date || ':00:00')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d$' THEN -- _dateute
  (_date || ':00')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d:\d\d(\.\d+)?((\+|\-)\d\d:\d\d)?$' THEN -- full date
  _date::timestamptz
ELSE
  NULL
END
$_$;


--
-- Name: _date_parse_to_upper(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _date_parse_to_upper(_date text) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT CASE
WHEN _date IS NULL THEN
  NULL
WHEN _date ~ '^\d\d\d\d$' THEN    -- year
  (_date || '-01-01 00:00:00')::timestamptz + interval '1 year' - interval '1 second'
WHEN _date ~ '^\d\d\d\d-\d\d$' THEN -- month
  (_date || '-01 00:00:00')::timestamptz + interval '1 month' - interval '1 second'
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d$' THEN -- day
  (_date || ' 23:59:59')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d$' THEN -- hour
  (_date || ':59:59')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d$' THEN -- _dateute
  (_date || ':59')::timestamptz
WHEN _date ~ '^\d\d\d\d-\d\d-\d\d( |T)\d\d:\d\d:\d\d(\.\d+)?((\+|\-)\d\d:\d\d)?$' THEN -- full date
  _date::timestamptz
ELSE
  NULL
END
$_$;


--
-- Name: _datetime_to_tstzrange(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _datetime_to_tstzrange(_min text, _max text) RETURNS tstzrange
    LANGUAGE sql
    AS $$
  SELECT CASE
  WHEN _min IS NULL THEN
    NULL
  WHEN _max is NULL AND _min IS NOT NULL THEN
     ('['|| _date_parse_to_lower(_min) || ',' || ')')::tstzrange
  WHEN _min is NULL AND _max IS NOT NULL THEN
     ('(,' || _date_parse_to_upper(_max) || ']' )::tstzrange
  WHEN _max is NOT NULL AND _min IS NOT NULL THEN
     ('['|| _date_parse_to_lower(_min) || ',' || _date_parse_to_upper(_max) || ']')::tstzrange
  ELSE
    NULL
  END
$$;


--
-- Name: _debug(anyelement); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _debug(x anyelement) RETURNS anyelement
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE NOTICE 'DEBUG %', x;
  RETURN x;
END
$$;


--
-- Name: _eval(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _eval(_str_ text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  EXECUTE _str_;
  RETURN _str_;
END;
$$;


--
-- Name: _expand_search_params(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _expand_search_params(_resource_type text, _query text) RETURNS SETOF query_param
    LANGUAGE sql
    AS $$
  WITH RECURSIVE params(parent_resource, link_path, res, chain, key, operator, value) AS (
    -- this is inital select
    -- it produce some rows where key length > 1
    -- and we expand them joining meta inforamtion
    SELECT null::text as parent_resource, -- we start with empty parent resoure
           '{}'::text[] as link_path, -- path of reference attribute to join
           _resource_type::text as res, -- this is resource to apply condition
           ARRAY[_resource_type]::text[] || key as chain,
           key as key,
           operator as operator,
           value as value
    FROM _parse_param(_query)
    WHERE key[1] NOT IN ('_tag', '_security', '_profile', '_sort', '_count', '_page')

    UNION

    SELECT res as parent_resource, -- move res to parent_resource
           _rest(ri.path) as link_path,
           get_reference_type(x.key[1], re.ref_type) as res, -- set next res in chain
           x.chain AS chain, -- save search path
           _rest(x.key) AS key, -- remove first item from key untill only one key left
           x.operator,
           x.value
     FROM  params x
     JOIN  fhir.resource_indexables ri
       ON  ri.param_name = split_part(key[1], ':',1)
      AND  ri.resource_type = x.res
     JOIN  fhir.resource_elements re
       ON  re.path = ri.path
    WHERE array_length(key,1) > 1
  )
  SELECT
    parent_resource as parent_resource,
    link_path as link_path,
    res as resource_type,
    _butlast(p.chain) as chain,
    ri.search_type,
    ri.is_primitive,
    ri.type,
    _rest(ri.path)::text[] as field_path,
    key[1] as key,
    operator,
    value
  FROM params p
  JOIN fhir.resource_indexables ri
    ON ri.resource_type = res
   AND ri.param_name = key[1]
 where array_length(key,1) = 1
  ORDER by p.chain
  ;
$$;


--
-- Name: _extract_id(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _extract_id(_id_ text) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT _last(regexp_split_to_array((regexp_split_to_array(_id_, '/_history/')::text[])[1], '/'));
$$;


--
-- Name: _extract_vid(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _extract_vid(_id_ text) RETURNS text
    LANGUAGE sql
    AS $$
  -- TODO: raise if not valid url
  SELECT _last(regexp_split_to_array(_id_, '/_history/'));
$$;


--
-- Name: _fhir_spilt_to_table(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _fhir_spilt_to_table(_str text) RETURNS TABLE(value text)
    LANGUAGE sql
    AS $_$
  SELECT _fhir_unescape_param(x)
   FROM regexp_split_to_table(regexp_replace(_str, $RE$([^\\]),$RE$, E'\\1,,,,,'), ',,,,,') x
$_$;


--
-- Name: _fhir_unescape_param(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _fhir_unescape_param(_str text) RETURNS text
    LANGUAGE sql
    AS $_$
  SELECT regexp_replace(_str, $RE$\\([,$|])$RE$, E'\\1', 'g')
$_$;


--
-- Name: _get_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _get_key(_key_ text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT array_to_string(_butlast(a) || split_part(_last(a), ':', 1), '.')
from regexp_split_to_array(_key_, '\.') a;
$$;


--
-- Name: _get_modifier(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _get_modifier(_key_ text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT nullif(split_part(_last(regexp_split_to_array(_key_,'\.')), ':',2), '');
$$;


--
-- Name: _is_array(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _is_array(_json jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT jsonb_typeof(_json) = 'array';
$$;


--
-- Name: _is_descedant(anyarray, anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _is_descedant(_parent_ anyarray, _child_ anyarray) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT _child_[array_lower(_parent_,1) : array_upper(_parent_,1)] = _parent_;
$$;


--
-- Name: _is_object(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _is_object(_json jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT jsonb_typeof(_json) = 'object';
$$;


--
-- Name: _last(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _last(_ar_ anyarray) RETURNS anyelement
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT _ar_[array_length(_ar_,1)];
$$;


--
-- Name: _lexit_int(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _lexit_int(_int numeric) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN _int = 0 THEN
      'a0'
    WHEN _int < 0 THEN
      lex_reverse(_lexit_int(-_int))
    ELSE
      (SELECT repeat('a', char_length(lex_prefix)) || lex_prefix || _int::text
        FROM lex_prefix('', _int))
    END;
$$;


--
-- Name: _merge_tags(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _merge_tags(_old_tags jsonb, _new_tags jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
 SELECT json_agg(x.x)::jsonb FROM (
   SELECT jsonb_array_elements(_new_tags) x
   UNION
   SELECT jsonb_array_elements(_old_tags) x
 ) x
$$;


--
-- Name: _parse_param(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _parse_param(_params_ text) RETURNS TABLE(key text[], operator text, value text[])
    LANGUAGE sql IMMUTABLE
    AS $$

WITH initial AS (
  -- split params by & and then split by = return (key, val) relation
  SELECT url_decode(split_part(x,'=',1)) as key,
         url_decode(split_part(x, '=', 2)) as val
    FROM regexp_split_to_table(_params_,'&') x
), with_op_mod AS (
  SELECT  _get_key(key) as key, -- normalize key (remove modifiers)
          _get_modifier(key) as mod, -- extract modifier
          CASE WHEN val ~ E'^(>=|<=|<|>|~).*' THEN
            regexp_replace(val, E'^(>=|<=|<|>|~).*','\1') -- extract operator
          ELSE
            NULL
          END as op,
          regexp_replace(val, E'^(>|<|<=|>=|~)(.*)','\2') as val
    FROM  initial
)
-- build resulting array
SELECT
  regexp_split_to_array(key, '\.') as key,
  COALESCE(op,mod,'=') as operator,
  regexp_split_to_array(_unaccent_string(val), ',') as value
FROM with_op_mod;

$$;


--
-- Name: _replace_references(text, json[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _replace_references(_resource_ text, _references_ json[]) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT
    CASE
    WHEN array_length(_references_, 1) > 0 THEN
     _replace_references(
       replace(_resource_, _references_[1]->>'alternative', _references_[1]->>'id'),
       _rest(_references_))
   ELSE _resource_
   END;
$$;


--
-- Name: _rest(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _rest(_ar_ anyarray) RETURNS anyarray
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT _ar_[2 : array_upper(_ar_,1)];
$$;


--
-- Name: _subpath(anyarray, anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _subpath(_parent_ anyarray, _child_ anyarray) RETURNS character varying[]
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT _child_[array_upper(_parent_,1) + 1 : array_upper(_child_,1)];
$$;


--
-- Name: _to_string(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _to_string(_text text) RETURNS text
    LANGUAGE sql
    AS $$
SELECT translate(_text,
  '"[]{}\\:,',
  '        ');
$$;


--
-- Name: _token_index_fn(character varying, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _token_index_fn(dtype character varying, is_primitive boolean) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT  'index_' || CASE WHEN is_primitive THEN 'primitive' ELSE lower(dtype::varchar) END || '_as_token'
$$;


--
-- Name: _tpl(text, character varying[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _tpl(_tpl_ text, VARIADIC _bindings character varying[]) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
--- replace {{var}} in template string
---  EXAMPLE:
---    _tpl('{{a}}={{b}}', 'a', 'A','b','B') => 'A=B'
DECLARE
  result text := _tpl_;
BEGIN
  FOR i IN 1..(array_upper(_bindings, 1)/2) LOOP
    result := replace(result, '{{' || _bindings[i*2 - 1] || '}}', coalesce(_bindings[i*2], ''));
  END LOOP;
  RETURN result;
END
$$;


--
-- Name: _unaccent_string(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _unaccent_string(_text text) RETURNS text
    LANGUAGE sql
    AS $$
SELECT translate(_text,
  'âãäåāăąÁÂÃÄÅĀĂĄèééêëēĕėęěĒĔĖĘĚìíîïìĩīĭÌÍÎÏÌĨĪĬóôõöōŏőÒÓÔÕÖŌŎŐùúûüũūŭůÙÚÛÜŨŪŬŮ',
  'aaaaaaaAAAAAAAAeeeeeeeeeeEEEEEiiiiiiiiIIIIIIIIoooooooOOOOOOOOuuuuuuuuUUUUUUUU');
$$;


--
-- Name: admin_disk_usage_top(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION admin_disk_usage_top(_limit integer) RETURNS TABLE(relname text, size text)
    LANGUAGE sql
    AS $$

  SELECT nspname || '.' || relname AS "relation",
  pg_size_pretty(pg_relation_size(C.oid)) AS "size"
  FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
  WHERE nspname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_relation_size(C.oid) DESC
  LIMIT _limit;

$$;


--
-- Name: assert(boolean, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION assert(_pred boolean, mess character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
  item jsonb;
  acc varchar[] := array[]::varchar[];
BEGIN
  IF _pred THEN
    RETURN 'OK ' || mess;
  ELSE
    RAISE EXCEPTION 'NOT OK %',  mess;
    RETURN 'not ok';
  END IF;
END
$$;


--
-- Name: assert_eq(anyelement, anyelement, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION assert_eq(expec anyelement, res anyelement, mess character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
  item jsonb;
  acc varchar[] := array[]::varchar[];
BEGIN
  IF expec = res  OR (expec IS NULL AND res IS NULL) THEN
    RETURN 'OK ' || mess;
  ELSE
    RAISE EXCEPTION E'assert_eq % FAILED:\nEXPECTED: %\nACTUAL:   %', mess, expec, res;
    RETURN 'NOT OK';
  END IF;
END
$$;


--
-- Name: assert_raise(character varying, text, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION assert_raise(exp character varying, str text, mess character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
BEGIN
  BEGIN
    EXECUTE str;
  EXCEPTION
    WHEN OTHERS THEN
      IF exp = SQLERRM THEN
        RETURN 'OK ' || mess;
    ELSE
      RAISE EXCEPTION E'assert_raise % FAILED:\nEXPECTED: %\nACTUAL:   %', mess, exp, SQLERRM;
      RETURN 'NOT OK';
    END IF;
  END;
  RAISE EXCEPTION E'assert_raise % FAILED:\nEXPECTED: %', mess, exp;
  RETURN 'NOT OK';
END
$$;


--
-- Name: build_cond(text, query_param); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_cond(tbl text, _q query_param) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT
  CASE
  WHEN _q.search_type = 'identifier' THEN
    build_identifier_cond(tbl, _q)
  WHEN _q.search_type = 'string' THEN
    build_string_cond(tbl, _q)
  WHEN _q.search_type = 'token' THEN
    build_token_cond(tbl, _q)
  WHEN _q.search_type = 'date' THEN
    build_date_cond(tbl, _q)
  WHEN _q.search_type = 'reference' THEN
    build_reference_cond(tbl, _q)
  END as cnd
$$;


--
-- Name: build_date_cond(text, query_param); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_date_cond(tbl text, _q query_param) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT
'(' ||
string_agg(
  format('index_as_date(content, %L, %L) && %L',
    _q.field_path,
    _q.type,
    (
      case
      when _q.operator = '=' then
        _datetime_to_tstzrange(v, v)
      when _q.operator = '>' then
        _datetime_to_tstzrange(v, NULL)
      when _q.operator = '<' then
        ('(,' || _date_parse_to_upper(v) || ']' )::tstzrange
      end
    )
  )
,' OR ')
|| ')'
FROM unnest(_q.value) v
$$;


--
-- Name: build_identifier_cond(text, query_param); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_identifier_cond(tbl text, _q query_param) RETURNS text
    LANGUAGE sql
    AS $$
SELECT format('%I.logical_id IN (%s)', tbl, string_agg((E'\'' || x || E'\'::uuid'),','))
FROM unnest(_q.value) x
$$;


--
-- Name: build_reference_cond(text, query_param); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_reference_cond(tbl text, _q query_param) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT
  format('index_as_reference(content, %L) && %L::varchar[]', _q.field_path, _q.value)
$$;


--
-- Name: build_search_query(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_search_query(_resource_type text, _query text) RETURNS text
    LANGUAGE sql
    AS $$
WITH conds AS (
  SELECT
    build_cond(lower(resource_type),row(x.*))::text as cond,
    resource_type,
    chain,
    link_path,
    parent_resource
  FROM  _expand_search_params(_resource_type, _query) x
), joins AS ( --TODO: what if no middle join present ie we have a.b.c.attr = x and no a.b.attr condition
  SELECT
    format(E'JOIN %I ON index_as_reference(%I.content, %L) && ARRAY[%I.logical_id]::varchar[] AND \n %s',
      lower(resource_type),
      lower(parent_resource),
      link_path,
      lower(resource_type),
      string_agg(cond, E'\nAND')) sql
    FROM conds
    WHERE parent_resource IS NOT NULL
    GROUP BY resource_type, parent_resource, chain, link_path
    ORDER by chain
), special_params AS (
  SELECT key[1] as key, value[1] as value
  FROM _parse_param(_query)
  where key[1] ilike '_%'
)

SELECT
format('SELECT %I.* FROM %I ', lower(_resource_type), lower(_resource_type))
|| E'\n' || COALESCE((SELECT string_agg(sql, E'\n')::text FROM joins), ' ')
|| E'\nWHERE '
|| COALESCE((SELECT string_agg(cond, ' AND ')
    FROM conds
    WHERE parent_resource IS NULL
    GROUP BY resource_type), ' true = true ')
|| COALESCE(build_sorting(_resource_type, _query), '')
|| format(E'\nLIMIT %s',COALESCE( (SELECT value::integer FROM special_params WHERE key = '_count'), '100'))
$$;


--
-- Name: build_sorting(character varying, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_sorting(_resource_type character varying, _query text) RETURNS text
    LANGUAGE sql
    AS $$

WITH params AS (
  SELECT ROW_NUMBER() OVER () as weight,
         value[1] as param_name,
         case when operator='desc'
          then 'DESC'
          else 'ASC'
          end as direction
    FROM _parse_param(_query) q
   WHERE key[1] = '_sort'
), with_meta AS (
  SELECT *
    FROM params x
    JOIN fhir.resource_indexables fr
      ON fr.resource_type = _resource_type
     AND fr.param_name = x.param_name
ORDER BY weight
)
SELECT k.column1
|| string_agg(
  format(E'(json_get_in(%I.content, \'%s\'))[1]::text %s', lower(_resource_type), _rest(y.path)::text, y.direction)
  ,E', ')
FROM with_meta y, (VALUES(E'\n ORDER BY ')) k -- we join for manadic effect, if no sorting parmas return null
GROUP BY k.column1
$$;


--
-- Name: build_string_cond(text, query_param); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_string_cond(tbl text, _q query_param) RETURNS text
    LANGUAGE sql
    AS $$
SELECT '(' || string_agg(
    format('index_as_string(%I.content, %L) ilike %L', tbl, _q.field_path, '%' || x || '%'),
    ' OR ') || ')'
FROM unnest(_q.value) x
$$;


--
-- Name: build_token_cond(text, query_param); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION build_token_cond(tbl text, _q query_param) RETURNS text
    LANGUAGE sql
    AS $$
SELECT
  format('%s(%I.content, %L) && %L::varchar[]',
    _token_index_fn(_q.type, _q.is_primitive),
    tbl,
    _q.field_path,
    _q.value)
$$;


--
-- Name: column_name(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION column_name(name character varying, type character varying) RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT replace(name, '[x]', '' || type);
$$;


--
-- Name: drop_resource_indexes(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION drop_resource_indexes(_resource text) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT count(_eval(format('DROP INDEX IF EXISTS "%s"',indname)))
  FROM (
      SELECT i.relname as indname,
      i.relowner as indowner,
      idx.indrelid::regclass,
      am.amname as indam,
      idx.indkey,
      ARRAY(
        SELECT pg_get_indexdef(idx.indexrelid, k + 1, true)
        FROM generate_subscripts(idx.indkey, 1) as k
        ORDER BY k
      ) as indkey_names,
      idx.indexprs IS NOT NULL as indexprs,
      idx.indpred IS NOT NULL as indpred
      FROM   pg_index as idx
      JOIN   pg_class as i
      ON     i.oid = idx.indexrelid
      JOIN   pg_am as am
      ON     i.relam = am.oid
      WHERE
      idx.indrelid::regclass = quote_ident(lower(_resource))::regclass
      and i.relname ilike '%_idx'
  ) idx;
$$;


--
-- Name: explain_search(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION explain_search(_resource_type text, query text) RETURNS TABLE(plan text)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY EXECUTE 'EXPLAIN ANALYZE ' || build_search_query(_resource_type, query);
END
$$;


--
-- Name: fhir_affix_tags(jsonb, text, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_affix_tags(_cfg jsonb, _res_type text, _id_ uuid, _tags jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
      UPDATE "{{tbl}}"
      SET category = _merge_tags(category, $2)
      WHERE logical_id = $1
      RETURNING category
    $SQL$, 'tbl', lower(_res_type))
    INTO res USING _id_, _tags;
  RETURN res;
END;
$_$;


--
-- Name: fhir_affix_tags(jsonb, text, uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_affix_tags(_cfg jsonb, _res_type text, _id_ uuid, _vid_ uuid, _tags jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
      WITH res AS (
        UPDATE "{{tbl}}"
        SET category = _merge_tags(category, $2)
        WHERE logical_id = $1 AND version_id = $3
        RETURNING category
      ), his AS (
        UPDATE "{{tbl}}_history"
        SET category = _merge_tags(category, $2)
        WHERE logical_id = $1 AND version_id = $3
        RETURNING category
      )
      SELECT * FROM res
      UNION
      SELECT * FROM his
    $SQL$, 'tbl', lower(_res_type))
    INTO res USING _id_, _tags, _vid_;
  RETURN res;
END;
$_$;


--
-- Name: fhir_conformance(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_conformance(_cfg jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
SELECT json_build_object(
  'resourceType', 'Conformance',
  'identifier', _cfg->'identifier',
  'version', _cfg->'version',
  'name', _cfg->'name',
  'publisher', _cfg->'publisher',
  'telecom', _cfg->'telecom',
  'description', _cfg->'description',
  'status', 'active',
  'date', _cfg->'date',
  'software', _cfg->'software',
  'fhirVersion', _cfg->'fhirVersion',
  'acceptUnknown', _cfg->'acceptUnknown',
  'format', _cfg->'format',
  'rest', ARRAY[json_build_object(
    'mode', 'server',
    'operation', ARRAY['{ "code": "transaction" }'::json, '{ "code": "history-system" }'::json],
    'cors', _cfg->'cors',
    'resource',
      (SELECT json_agg(
          json_build_object(
            'type', e.path[1],
            'profile', json_build_object(
              'reference', _cfg->>'base' || '/Profile/' || e.path[1]
            ),
            'readHistory', true,
            'updateCreate', true,
            'operation', ARRAY['{ "code": "read" }'::json, '{ "code": "vread" }'::json, '{ "code": "update" }'::json, '{ "code": "history-instance" }'::json, '{ "code": "create" }'::json, '{ "code": "history-type" }'::json],
            'searchParam',  (
              SELECT  json_agg(t.*)  FROM (
                SELECT sp.name, sp.type, sp.documentation
                FROM fhir.resource_search_params sp
                  WHERE sp.path[1] = e.path[1]
              ) t
            )

          )
        )
        FROM fhir.resource_elements e
        WHERE array_length(path,1) = 1
      )
  )]
)::jsonb;
$$;


--
-- Name: fhir_create(jsonb, text, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_create(_cfg jsonb, _type text, _resource jsonb, _tags jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
  SELECT fhir_create(_cfg, _type, gen_random_uuid(), _resource, _tags);
$$;


--
-- Name: fhir_create(jsonb, text, uuid, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_create(_cfg jsonb, _type text, _id uuid, _resource jsonb, _tags jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  __published timestamptz :=  CURRENT_TIMESTAMP;
  __vid uuid := gen_random_uuid();
BEGIN
  EXECUTE
    _tpl($SQL$
      INSERT INTO "{{tbl}}"
      (logical_id, version_id, published, updated, content, category)
      VALUES
      ($1, $2, $3, $4, $5, $6)
    $SQL$, 'tbl', lower(_type))
  USING _id, __vid, __published, __published, _resource, _tags;

  RETURN fhir_read(_cfg, _type, _id::text);
END
$_$;


--
-- Name: fhir_delete(jsonb, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_delete(_cfg jsonb, _type text, _url text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  __bundle jsonb;
BEGIN
  __bundle := fhir_read(_cfg, _type, _url);

  EXECUTE
    _tpl($SQL$
      INSERT INTO "{{tbl}}_history"
      (logical_id, version_id, published, updated, content, category)
      SELECT
      logical_id, version_id, published, current_timestamp, content, category
      FROM "{{tbl}}" WHERE logical_id = $1 LIMIT 1;

      DELETE FROM "{{tbl}}" WHERE logical_id = $1;
    $SQL$, 'tbl', lower(_type))
  USING _extract_id(_url)::uuid;

  RETURN __bundle;
END
$_$;


--
-- Name: fhir_history(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_history(_cfg jsonb, _params_ jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
        UNION
        SELECT * FROM resource_history
      ) r
  )
  SELECT _build_bundle(
    'History of all resources',
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );
$$;


--
-- Name: fhir_history(jsonb, character varying, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_history(_cfg jsonb, _type_ character varying, _params_ jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
      ) r
  )
  SELECT _build_bundle(
    'History of resource by type =' || _type_,
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );
$$;


--
-- Name: fhir_history(jsonb, character varying, character varying, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_history(_cfg jsonb, _type_ character varying, _url_ character varying, _params_ jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
      ) r
  )
  SELECT _build_bundle(
    'History of resource by id=' || _extract_id(_url_),
    (SELECT count(*)::int FROM entry),
    (SELECT json_agg(entry) FROM entry e)
  );
$$;


--
-- Name: fhir_is_deleted_resource(jsonb, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_is_deleted_resource(_cfg jsonb, _type_ text, _id_ text) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT
  EXISTS (
    SELECT * FROM resource_history
     WHERE resource_type = _type_
       AND logical_id = _id_::uuid
  ) AND NOT EXISTS (
    SELECT * FROM resource
     WHERE resource_type = _type_
       AND logical_id = _id_::uuid
  )
$$;


--
-- Name: fhir_is_latest_resource(jsonb, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_is_latest_resource(_cfg jsonb, _type_ text, _id_ text, _vid_ text) RETURNS boolean
    LANGUAGE sql
    AS $$
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _id_::uuid
       AND r.version_id = _vid_::uuid
    )
$$;


--
-- Name: fhir_is_resource_exists(jsonb, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_is_resource_exists(_cfg jsonb, _type_ text, _id_ text) RETURNS boolean
    LANGUAGE sql
    AS $$
    SELECT EXISTS (
      SELECT * FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _id_::uuid
    )
$$;


--
-- Name: fhir_profile(jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_profile(_cfg jsonb, _resource_name_ text) RETURNS jsonb
    LANGUAGE sql
    AS $$
WITH elems AS (
  SELECT array_to_string(e.path,'.') as path,
         json_build_object(
           'min', e.min,
           'max', e.max,
           'type', COALESCE((SELECT json_agg(tt.*) FROM (SELECT t as code FROM unnest(e.type) t) tt), '[]'::json)
         ) as definition
    FROM fhir.resource_elements e
   WHERE path[1]=_resource_name_
), params AS (
  SELECT sp.name, sp.type, sp.documentation, array_to_string(sp.path, '/') as xpath
  FROM fhir.resource_search_params sp
    WHERE sp.path[1] = _resource_name_
)
SELECT json_build_object(
   'name', _resource_name_,
   'resourceType', 'Profile',
   'structure', ARRAY[json_build_object(
     'type', _resource_name_,
     'publish', true,
     'differential', json_build_object(
       'element', (SELECT json_agg(t.*) FROM elems  t)
     ),
     'searchParam',  (SELECT  json_agg(t.*)  FROM params t)
   )]
)::jsonb
$$;


--
-- Name: fhir_read(jsonb, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_read(_cfg jsonb, _type_ text, _url_ text) RETURNS jsonb
    LANGUAGE sql
    AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM resource r
     WHERE r.resource_type = _type_
       AND r.logical_id = _extract_id(_url_)::uuid)
  SELECT _build_bundle('Concrete resource by id ' || _extract_id(_url_), 1, (SELECT json_agg(entry) FROM entry));
$$;


--
-- Name: fhir_remove_tags(jsonb, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_remove_tags(_cfg jsonb, _res_type text, _id_ uuid) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
      UPDATE "{{tbl}}"
      SET category = '[]'::jsonb
      WHERE logical_id = $1
    $SQL$, 'tbl', lower(_res_type))
  USING _id_;

  RETURN 1;
END;
$_$;


--
-- Name: fhir_remove_tags(jsonb, text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_remove_tags(_cfg jsonb, _res_type text, _id_ uuid, _vid_ uuid) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE
  res jsonb;
BEGIN
  EXECUTE
    _tpl($SQL$
      WITH res AS (
        UPDATE "{{tbl}}"
        SET category = '[]'::jsonb
        WHERE logical_id = $1 AND version_id = $2
        RETURNING 1
      ), his AS (
        UPDATE "{{tbl}}_history"
        SET category = '[]'::jsonb
        WHERE logical_id = $1 AND version_id = $2
        RETURNING 1
      )
      SELECT * FROM res, his
    $SQL$, 'tbl', lower(_res_type))
    USING _id_, _vid_;
  RETURN 1;
END;
$_$;


--
-- Name: fhir_search(jsonb, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_search(_cfg jsonb, _type_ text, _params_ text) RETURNS jsonb
    LANGUAGE sql
    AS $$
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM search(_type_, _params_) r
  )
  SELECT _build_bundle(
    'Search ' || _type_  || ' by ' || _params_,
    (SELECT count(*)::int FROM entry),
    (SELECT COALESCE(json_agg(entry),'[]'::json) FROM entry e)
  );
$$;


--
-- Name: fhir_tags(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_tags(_cfg jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', '["todo"]'::json
  )::jsonb
$$;


--
-- Name: FUNCTION fhir_tags(_cfg jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION fhir_tags(_cfg jsonb) IS 'Return all tags in system';


--
-- Name: fhir_tags(jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_tags(_cfg jsonb, _res_type text) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', '["todo"]'::json
  )::jsonb
$$;


--
-- Name: fhir_tags(jsonb, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_tags(_cfg jsonb, _res_type text, _id_ uuid) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', coalesce((
      SELECT r.category::json
      FROM resource r
      WHERE r.resource_type = _res_type
      AND r.logical_id = _id_
    ), NULL::json))::jsonb
$$;


--
-- Name: fhir_tags(jsonb, text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_tags(_cfg jsonb, _res_type text, _id_ uuid, _vid uuid) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT json_build_object(
    'resourceType',  'TagList',
    'category', coalesce(
     (
         SELECT category::json FROM (
          SELECT r.category FROM resource r
           WHERE r.resource_type = _res_type
             AND r.logical_id = _id_ AND r.version_id = _vid
          UNION
          SELECT r.category FROM resource_history r
           WHERE r.resource_type = _res_type
             AND r.logical_id = _id_ AND r.version_id = _vid
        ) x LIMIT 1
    ),
    NULL::json))::jsonb
$$;


--
-- Name: fhir_transaction(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_transaction(_cfg jsonb, _bundle_ jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
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


--
-- Name: FUNCTION fhir_transaction(_cfg jsonb, _bundle_ jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION fhir_transaction(_cfg jsonb, _bundle_ jsonb) IS 'Update, create or delete a set of resources as a single transaction\nReturns bundle with entries';


--
-- Name: fhir_update(jsonb, text, text, text, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_update(_cfg jsonb, _type text, _url_ text, _location_ text, _resource_ jsonb, _tags_ jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  __vid uuid;
BEGIN
  __vid := (SELECT version_id FROM resource WHERE logical_id = _extract_id(_url_)::uuid);

  IF _extract_vid(_location_)::uuid <> __vid THEN
    RAISE EXCEPTION E'Wrong version_id %. Current is %',
    _extract_vid(_location_), __vid;
    RETURN NULL;
  END IF;

  EXECUTE
    _tpl($SQL$
      INSERT INTO "{{tbl}}_history"
      (logical_id, version_id, published, updated, content, category)
      SELECT
      logical_id, version_id, published, current_timestamp, content, category
      FROM "{{tbl}}" WHERE version_id = $1 LIMIT 1
    $SQL$, 'tbl', lower(_type))
  USING __vid;

  EXECUTE
    _tpl($SQL$
      UPDATE "{{tbl}}" SET
      version_id = gen_random_uuid(),
      content = $2,
      category = _merge_tags(category, $3),
      updated = current_timestamp
      WHERE version_id = $1
    $SQL$, 'tbl', lower(_type))
  USING __vid, _resource_, _tags_;

  RETURN fhir_read(_cfg, _type , _extract_id(_url_));
END
$_$;


--
-- Name: FUNCTION fhir_update(_cfg jsonb, _type text, _url_ text, _location_ text, _resource_ jsonb, _tags_ jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION fhir_update(_cfg jsonb, _type text, _url_ text, _location_ text, _resource_ jsonb, _tags_ jsonb) IS 'Update resource, creating new version\nReturns bundle with one entry';


--
-- Name: fhir_vread(jsonb, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fhir_vread(_cfg jsonb, _type_ text, _url_ text) RETURNS jsonb
    LANGUAGE sql
    AS $$
--- Read the state of a specific version of the resource
--- return bundle with one entry
  WITH entry AS (
    SELECT _build_entry(_cfg, row(r.*)) as entry
      FROM (
        SELECT * FROM resource
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
           AND version_id = _extract_vid(_url_)::uuid
        UNION
        SELECT * FROM resource_history
         WHERE resource_type = _type_
           AND logical_id = _extract_id(_url_)::uuid
           AND version_id = _extract_vid(_url_)::uuid) r)
  SELECT _build_bundle('Version of resource by id=' || _extract_id(_url_) || ' vid=' || _extract_vid(_url_),
    1,
    (SELECT json_agg(entry) FROM entry e));
$$;


--
-- Name: FUNCTION fhir_vread(_cfg jsonb, _type_ text, _url_ text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION fhir_vread(_cfg jsonb, _type_ text, _url_ text) IS 'Read specific version of resource with _type_\nReturns bundle with one entry';


--
-- Name: fpath(character varying, xml); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fpath(pth character varying, x xml) RETURNS xml[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
  BEGIN
    return xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']]);
  END
$$;


--
-- Name: get_reference_type(text, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_reference_type(_key text, _types text[]) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT
        CASE WHEN position(':' in _key ) > 0 THEN
           split_part(_key, ':', 2)
        WHEN array_length(_types, 1) = 1 THEN
          _types[1]
        ELSE
          null -- TODO: think about this case
        END
$$;


--
-- Name: index_all_resources(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_all_resources() RETURNS TABLE(idx text)
    LANGUAGE sql
    AS $$
  SELECT
  _eval(index_search_param_exp(ROW(x.*)))
  from fhir.resource_indexables x
  where search_type IN ('token', 'reference', 'string', 'date')
$$;


--
-- Name: index_as_date(jsonb, text[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_as_date(content jsonb, path text[], type text) RETURNS tstzrange
    LANGUAGE sql IMMUTABLE
    AS $$

WITH dates AS (
  SELECT x
  FROM unnest(json_get_in(content, path)) x
  WHERE x is not null
)
SELECT
CASE
WHEN type = 'dateTime' OR type = 'date' OR type = 'instant' then
  (SELECT _datetime_to_tstzrange(min(jsonb_primitive_to_text(x)),max(jsonb_primitive_to_text(x)::text)) FROM dates x)
WHEN type = 'Period' then
  (SELECT _datetime_to_tstzrange(min(x->>'start'), max(x->>'end')) FROM dates x)
WHEN type = 'Schedule' then
  (
    --TODO: take duration into account
    SELECT _datetime_to_tstzrange(min(y.mind::text),  max(y.maxd)) FROM (
      SELECT
      x#>>'{event,0,start}' as mind,
      COALESCE((x#>>'{event,0,end}'),(x#>>'{repeat,end}')) as maxd
      FROM dates x
    ) y
    WHERE y.mind IS NOT NULL
  )
END
$$;


--
-- Name: index_as_reference(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_as_reference(content jsonb, path text[]) RETURNS character varying[]
    LANGUAGE sql IMMUTABLE
    AS $$
WITH idents AS (
  SELECT unnest as cd
  FROM unnest(json_get_in(content, path))
)
SELECT array_agg(x)::varchar[] FROM (
  SELECT cd->>'reference' as x
  from idents
  UNION
  SELECT _last(regexp_split_to_array(cd->>'reference', '\/')) as x
  from idents
) _
$$;


--
-- Name: index_as_string(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_as_string(content jsonb, path text[]) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT
regexp_replace(
  _to_string(_unaccent_string(json_get_in(content, path)::text))::text,
  E'\\s+', ' ', 'g')
$$;


--
-- Name: index_codeableconcept_as_token(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_codeableconcept_as_token(content jsonb, path text[]) RETURNS character varying[]
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT index_coding_as_token(content, array_append(path,'coding'));
$$;


--
-- Name: index_coding_as_token(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_coding_as_token(content jsonb, path text[]) RETURNS character varying[]
    LANGUAGE sql IMMUTABLE
    AS $$
WITH codings AS (
  SELECT unnest as cd
  FROM unnest(json_get_in(content, path))
)
SELECT array_agg(x)::varchar[] FROM (
  SELECT cd->>'code' as x
  from codings
  UNION
  SELECT cd->>'system' || '|' || (cd->>'code') as x
  from codings
) _
$$;


SET search_path = fhir, pg_catalog;

--
-- Name: resource_indexables; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE resource_indexables (
    param_name text,
    resource_type text,
    path character varying[],
    search_type text,
    type text,
    is_primitive boolean
);


SET search_path = public, pg_catalog;

--
-- Name: index_date_exp(fhir.resource_indexables); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_date_exp(_meta fhir.resource_indexables) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIST (index_as_date(content,%L::text[], %L) range_ops)'
      ,replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
      ,lower(_meta.resource_type)
      ,_rest(_meta.path)::varchar
      ,_meta.type
    )
$$;


--
-- Name: index_identifier_as_token(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_identifier_as_token(content jsonb, path text[]) RETURNS character varying[]
    LANGUAGE sql IMMUTABLE
    AS $$
WITH idents AS (
  SELECT unnest as cd
  FROM unnest(json_get_in(content, path))
)
SELECT array_agg(x)::varchar[] FROM (
  SELECT cd->>'value' as x
  from idents
  UNION
  SELECT cd->>'system' || '|' || (cd->>'value') as x
  from idents
) _
$$;


--
-- Name: index_primitive_as_token(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_primitive_as_token(content jsonb, path text[]) RETURNS character varying[]
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT
array_agg(jsonb_primitive_to_text(unnest::jsonb))::varchar[]
FROM unnest(json_get_in(content, path))
$$;


--
-- Name: index_reference_exp(fhir.resource_indexables); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_reference_exp(_meta fhir.resource_indexables) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT
    format(
      'CREATE INDEX %I ON %I USING GIN (index_as_reference(content,%L))'
      ,replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
      ,lower(_meta.resource_type)
      ,_rest(_meta.path)::varchar
    )
$$;


--
-- Name: index_resource(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_resource(_resource text) RETURNS TABLE(idx text)
    LANGUAGE sql
    AS $$
  SELECT
  _eval(index_search_param_exp(ROW(x.*)))
  from fhir.resource_indexables x
  where search_type IN ('token', 'reference', 'string', 'date')
  and resource_type = _resource
$$;


--
-- Name: index_search_param(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_search_param(_resource_type text, _param_name text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT count(_eval(index_search_param_exp(ROW(x.*))))::text
  FROM fhir.resource_indexables x
  WHERE resource_type = _resource_type
  AND  param_name = _param_name
$$;


--
-- Name: index_search_param_exp(fhir.resource_indexables); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_search_param_exp(x fhir.resource_indexables) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
 SELECT
 CASE
   WHEN x.search_type = 'token' THEN index_token_exp(x)
   WHEN x.search_type = 'reference' THEN index_reference_exp(x)
   WHEN x.search_type = 'string' THEN index_string_exp(x)
   WHEN x.search_type = 'date' THEN index_string_exp(x)
   ELSE ''
 END
$$;


--
-- Name: index_string_exp(fhir.resource_indexables); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_string_exp(_meta fhir.resource_indexables) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT
    format(
       'CREATE INDEX %I ON %I USING GIN (index_as_string(content,%L::text[]) gin_trgm_ops)'
      ,replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
      ,lower(_meta.resource_type)
      ,_rest(_meta.path)::varchar
    )
$$;


--
-- Name: index_token_exp(fhir.resource_indexables); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION index_token_exp(_meta fhir.resource_indexables) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT
   format(
    'CREATE INDEX %I ON %I USING GIN (%s(content,%L))'
    , replace(lower(_meta.resource_type || '_' || _meta.param_name || '_' || _last(_meta.path) || '_token_idx')::varchar,'-','_')
    , lower(_meta.resource_type)
    , _token_index_fn(_meta.type, _meta.is_primitive)
    , _rest(_meta.path)::varchar
   )
$$;


--
-- Name: json_array_to_str_array(jsonb[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION json_array_to_str_array(_jsons jsonb[]) RETURNS character varying[]
    LANGUAGE plpgsql
    AS $$
DECLARE
  item jsonb;
  acc varchar[] := array[]::varchar[];
BEGIN
  FOR item IN
    SELECT unnest(_jsons)
  LOOP
    acc := acc || (json_build_object('x', item)->>'x')::varchar;
  END LOOP;
  RETURN acc;
END
$$;


--
-- Name: json_get_in(jsonb, character varying[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION json_get_in(json jsonb, path character varying[]) RETURNS jsonb[]
    LANGUAGE plpgsql
    AS $$
DECLARE
  item jsonb;
  acc jsonb[] := array[]::jsonb[];
BEGIN
  --RAISE NOTICE 'in with % and path %', json, path;
  IF json is NULL THEN
    --RAISE NOTICE 'ups';
    RETURN array[]::jsonb[];
  END IF;

  IF array_length(path, 1) IS NULL THEN
    -- expand array
    IF _is_array(json) THEN
      FOR item IN SELECT jsonb_array_elements(json)
      LOOP
        acc := acc || item;
      END LOOP;
      RETURN acc;
    ELSE
      RETURN array[json];
    END IF;
  END IF;

  IF _is_array(json) THEN
    FOR item IN SELECT jsonb_array_elements(json)
    LOOP
      acc := acc || json_get_in(item,path);
    END LOOP;
    RETURN acc;
  ELSIF _is_object(json) THEN
    RETURN json_get_in(json->path[1], _rest(path));
  ELSE
    RETURN array[]::jsonb[];
  END IF;
END
$$;


--
-- Name: jsonb_primitive_to_text(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION jsonb_primitive_to_text(x jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE
 WHEN jsonb_typeof(x) = 'null' THEN
   NULL
 ELSE
   json_build_object('x', x)->>'x'
END
$$;


--
-- Name: jsonb_text_value(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION jsonb_text_value(j jsonb) RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT (json_build_object('x', j::json)->>'x')::varchar
$$;


--
-- Name: lex_prefix(text, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lex_prefix(_acc text, _int numeric) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN char_length(_int::text) > 9 THEN
      lex_prefix(char_length(_int::text) || _acc,
                 char_length(_int::text))
    ELSE
      char_length(_int::text) || _acc
    END;
$$;


--
-- Name: lex_reverse(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lex_reverse(_int text) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT string_agg(CASE
                    WHEN regexp_split_to_table = 'a' THEN
                      '!'
                    WHEN regexp_split_to_table = '!' THEN
                      'a'
                    ELSE
                      (9 - regexp_split_to_table::int)::text
                    END, '')
    FROM regexp_split_to_table(_int, '')
$$;


--
-- Name: lexit(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lexit(_dec numeric) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT CASE
    WHEN _dec = 0 THEN
      'a0'
    WHEN _dec > 0 AND _dec < 1 THEN
      'a0' || regexp_replace(_dec::text, '^0\.', '') || '!'
    WHEN _dec < 0 AND _dec > - 1 THEN
      lex_reverse(lexit(-_dec))
    WHEN  _dec > 1 THEN
      _lexit_int(round(_dec)) || lexit(('0.' || split_part(_dec::text,'.',2))::decimal)
    WHEN _dec < -1 THEN
      lex_reverse(_lexit_int(round(-_dec)) || lexit(('0.' || split_part(_dec::text,'.',2))::decimal))
    END;
$$;


--
-- Name: lexit(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lexit(_int bigint) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT _lexit_int(_int::decimal);
$$;


--
-- Name: lexit(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lexit(_str text) RETURNS text
    LANGUAGE sql
    AS $$
  select _str;
$$;


--
-- Name: profile_to_resource_type(character varying[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION profile_to_resource_type(profiles character varying[]) RETURNS character varying[]
    LANGUAGE sql
    AS $$
  SELECT array_agg(replace("unnest", 'http://hl7.org/fhir/profiles/', ''))::varchar[]
  FROM unnest(profiles);
$$;


--
-- Name: search(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION search(_resource_type text, query text) RETURNS SETOF resource
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  RETURN QUERY EXECUTE build_search_query(_resource_type, query);
END
$$;


--
-- Name: url_decode(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION url_decode(input text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
bin bytea = '';
byte text;
BEGIN
  FOR byte IN (select (regexp_matches(input, '(%..|.)', 'g'))[1]) LOOP
    IF length(byte) = 3 THEN
      bin = bin || decode(substring(byte, 2, 2), 'hex');
    ELSE
      bin = bin || byte::bytea;
    END IF;
  END LOOP;
  RETURN convert_from(bin, 'utf8');
END
$$;


--
-- Name: xarrattr(character varying, xml); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION xarrattr(pth character varying, x xml) RETURNS character varying[]
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RETURN array(select unnest(fpath(pth, x))::varchar);
  END
$$;


--
-- Name: xattr(character varying, xml); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION xattr(pth character varying, x xml) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN unnest(xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']])) limit 1;
END
$$;


--
-- Name: xsattr(character varying, xml); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION xsattr(pth character varying, x xml) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  RETURN unnest(xspath( pth,x)) limit 1;
END
$$;


--
-- Name: xspath(character varying, xml); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION xspath(pth character varying, x xml) RETURNS xml[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  return  xpath('/xml' || pth, xml('<xml xmlns:xs="xs">' || x || '</xml>'), ARRAY[ARRAY['xs','xs']]);
END
$$;


SET search_path = fhir, pg_catalog;

--
-- Name: datatype_elements; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE datatype_elements (
    version character varying,
    datatype character varying NOT NULL,
    name character varying NOT NULL,
    type character varying,
    min_occurs character varying,
    max_occurs character varying,
    documentation text
);


--
-- Name: datatype_enums; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE datatype_enums (
    version character varying,
    datatype character varying NOT NULL,
    value character varying NOT NULL,
    documentation text
);


--
-- Name: datatypes; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE datatypes (
    version character varying,
    type character varying NOT NULL,
    kind character varying,
    extension character varying,
    restriction_base character varying,
    documentation text[]
);


--
-- Name: enums; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW enums AS
 SELECT replace((datatype_enums.datatype)::text, '-list'::text, ''::text) AS enum,
    array_agg(datatype_enums.value) AS options
   FROM datatype_enums
  GROUP BY replace((datatype_enums.datatype)::text, '-list'::text, ''::text);


--
-- Name: hardcoded_complex_params; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE hardcoded_complex_params (
    path character varying[],
    type character varying
);


--
-- Name: resource_elements; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE resource_elements (
    version character varying,
    path character varying[] NOT NULL,
    min character varying,
    max character varying,
    type character varying[],
    ref_type character varying[]
);


--
-- Name: resource_search_params; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE resource_search_params (
    _id integer NOT NULL,
    path character varying[],
    name character varying,
    version character varying,
    type character varying,
    documentation text
);


--
-- Name: resource_search_params__id_seq; Type: SEQUENCE; Schema: fhir; Owner: -
--

CREATE SEQUENCE resource_search_params__id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_search_params__id_seq; Type: SEQUENCE OWNED BY; Schema: fhir; Owner: -
--

ALTER SEQUENCE resource_search_params__id_seq OWNED BY resource_search_params._id;


--
-- Name: search_type_to_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE search_type_to_type (
    stp text,
    tp character varying[]
);


SET search_path = public, pg_catalog;

--
-- Name: adversereaction; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE adversereaction (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'AdverseReaction'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: resource_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE resource_history (
    version_id uuid,
    logical_id uuid,
    resource_type character varying,
    updated timestamp with time zone,
    published timestamp with time zone,
    category jsonb,
    content jsonb
);


--
-- Name: adversereaction_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE adversereaction_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'AdverseReaction'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: alert; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE alert (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Alert'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: alert_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE alert_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Alert'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: allergyintolerance; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE allergyintolerance (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'AllergyIntolerance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: allergyintolerance_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE allergyintolerance_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'AllergyIntolerance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: careplan; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE careplan (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'CarePlan'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: careplan_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE careplan_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'CarePlan'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: composition; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE composition (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Composition'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: composition_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE composition_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Composition'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: conceptmap; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE conceptmap (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'ConceptMap'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: conceptmap_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE conceptmap_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'ConceptMap'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: condition; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE condition (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Condition'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: condition_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE condition_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Condition'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: conformance; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE conformance (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Conformance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: conformance_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE conformance_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Conformance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: device; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE device (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Device'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: device_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE device_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Device'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: deviceobservationreport; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE deviceobservationreport (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'DeviceObservationReport'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: deviceobservationreport_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE deviceobservationreport_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'DeviceObservationReport'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: diagnosticorder; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE diagnosticorder (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'DiagnosticOrder'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: diagnosticorder_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE diagnosticorder_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'DiagnosticOrder'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: diagnosticreport; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE diagnosticreport (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'DiagnosticReport'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: diagnosticreport_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE diagnosticreport_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'DiagnosticReport'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: documentmanifest; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE documentmanifest (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'DocumentManifest'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: documentmanifest_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE documentmanifest_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'DocumentManifest'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: documentreference; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE documentreference (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'DocumentReference'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: documentreference_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE documentreference_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'DocumentReference'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: encounter; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE encounter (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Encounter'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: encounter_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE encounter_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Encounter'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: familyhistory; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE familyhistory (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'FamilyHistory'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: familyhistory_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE familyhistory_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'FamilyHistory'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: group; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "group" (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Group'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: group_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE group_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Group'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: imagingstudy; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE imagingstudy (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'ImagingStudy'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: imagingstudy_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE imagingstudy_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'ImagingStudy'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: immunization; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE immunization (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Immunization'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: immunization_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE immunization_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Immunization'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: immunizationrecommendation; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE immunizationrecommendation (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'ImmunizationRecommendation'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: immunizationrecommendation_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE immunizationrecommendation_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'ImmunizationRecommendation'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: list; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE list (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'List'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: list_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE list_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'List'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: location; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE location (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Location'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: location_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE location_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Location'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: media; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE media (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Media'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: media_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE media_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Media'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: medication; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medication (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Medication'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: medication_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medication_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Medication'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: medicationadministration; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationadministration (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'MedicationAdministration'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: medicationadministration_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationadministration_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'MedicationAdministration'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: medicationdispense; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationdispense (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'MedicationDispense'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: medicationdispense_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationdispense_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'MedicationDispense'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: medicationprescription; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationprescription (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'MedicationPrescription'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: medicationprescription_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationprescription_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'MedicationPrescription'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: medicationstatement; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationstatement (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'MedicationStatement'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: medicationstatement_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE medicationstatement_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'MedicationStatement'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: messageheader; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE messageheader (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'MessageHeader'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: messageheader_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE messageheader_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'MessageHeader'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: observation; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE observation (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Observation'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: observation_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE observation_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Observation'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: operationoutcome; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE operationoutcome (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'OperationOutcome'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: operationoutcome_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE operationoutcome_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'OperationOutcome'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: order; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "order" (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Order'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: order_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE order_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Order'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: orderresponse; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE orderresponse (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'OrderResponse'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: orderresponse_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE orderresponse_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'OrderResponse'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: organization; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE organization (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Organization'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: organization_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE organization_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Organization'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: other; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE other (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Other'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: other_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE other_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Other'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: patient; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE patient (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Patient'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: patient_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE patient_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Patient'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: practitioner; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE practitioner (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Practitioner'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: practitioner_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Practitioner'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: procedure; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE procedure (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Procedure'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: procedure_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE procedure_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Procedure'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: profile; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE profile (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Profile'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: profile_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE profile_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Profile'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: provenance; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE provenance (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Provenance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: provenance_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE provenance_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Provenance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: query; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE query (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Query'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: query_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE query_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Query'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: questionnaire; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Questionnaire'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: questionnaire_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Questionnaire'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: relatedperson; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE relatedperson (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'RelatedPerson'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: relatedperson_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE relatedperson_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'RelatedPerson'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: securityevent; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE securityevent (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'SecurityEvent'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: securityevent_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE securityevent_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'SecurityEvent'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: specimen; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE specimen (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Specimen'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: specimen_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE specimen_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Specimen'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: substance; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE substance (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Substance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: substance_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE substance_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Substance'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: supply; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE supply (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'Supply'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: supply_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE supply_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'Supply'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


--
-- Name: ucum_prefixes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE ucum_prefixes (
    code character varying,
    big_code character varying,
    name character varying,
    symbol character varying,
    value numeric,
    value_text character varying
);


--
-- Name: ucum_units; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE ucum_units (
    code character varying,
    is_metric character varying,
    class character varying,
    name character varying,
    symbol character varying,
    property character varying,
    unit character varying,
    value character varying,
    value_text character varying,
    func_name character varying,
    func_value numeric,
    func_unit character varying
);


--
-- Name: valueset; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE valueset (
    version_id uuid DEFAULT gen_random_uuid(),
    logical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying DEFAULT 'ValueSet'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource);


--
-- Name: valueset_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE valueset_history (
    version_id uuid NOT NULL,
    logical_id uuid NOT NULL,
    resource_type character varying DEFAULT 'ValueSet'::character varying,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    published timestamp with time zone DEFAULT now() NOT NULL,
    category jsonb,
    content jsonb NOT NULL
)
INHERITS (resource_history);


SET search_path = fhir, pg_catalog;

--
-- Name: _id; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY resource_search_params ALTER COLUMN _id SET DEFAULT nextval('resource_search_params__id_seq'::regclass);


--
-- Data for Name: datatype_elements; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY datatype_elements (version, datatype, name, type, min_occurs, max_occurs, documentation) FROM stdin;
0.12	BackboneElement	modifierExtension	Extension	0	unbounded	\N
0.12	Resource	language	code	0	1	\N
0.12	Resource	text	Narrative	0	1	\N
0.12	Resource	contained	Resource.Inline	0	unbounded	\N
0.12	Narrative	status	NarrativeStatus	1	1	\N
0.12	Narrative	div	text	1	1	\N
0.12	Period	start	dateTime	0	1	\N
0.12	Period	end	dateTime	0	1	\N
0.12	Coding	system	uri	0	1	\N
0.12	Coding	version	string	0	1	\N
0.12	Coding	code	code	0	1	\N
0.12	Coding	display	string	0	1	\N
0.12	Coding	primary	boolean	0	1	\N
0.12	Coding	valueSet	ResourceReference	0	1	\N
0.12	Range	low	Quantity	0	1	\N
0.12	Range	high	Quantity	0	1	\N
0.12	Quantity	value	decimal	0	1	\N
0.12	Quantity	comparator	QuantityCompararator	0	1	\N
0.12	Quantity	units	string	0	1	\N
0.12	Quantity	system	uri	0	1	\N
0.12	Quantity	code	code	0	1	\N
0.12	Attachment	contentType	code	1	1	\N
0.12	Attachment	language	code	0	1	\N
0.12	Attachment	data	base64Binary	0	1	\N
0.12	Attachment	url	uri	0	1	\N
0.12	Attachment	size	integer	0	1	\N
0.12	Attachment	hash	base64Binary	0	1	\N
0.12	Attachment	title	string	0	1	\N
0.12	Ratio	numerator	Quantity	0	1	\N
0.12	Ratio	denominator	Quantity	0	1	\N
0.12	SampledData	origin	Quantity	1	1	\N
0.12	SampledData	period	decimal	1	1	\N
0.12	SampledData	factor	decimal	0	1	\N
0.12	SampledData	lowerLimit	decimal	0	1	\N
0.12	SampledData	upperLimit	decimal	0	1	\N
0.12	SampledData	dimensions	integer	1	1	\N
0.12	SampledData	data	SampledDataDataType	1	1	\N
0.12	ResourceReference	reference	string	0	1	\N
0.12	ResourceReference	display	string	0	1	\N
0.12	CodeableConcept	coding	Coding	0	unbounded	\N
0.12	CodeableConcept	text	string	0	1	\N
0.12	Identifier	use	IdentifierUse	0	1	\N
0.12	Identifier	label	string	0	1	\N
0.12	Identifier	system	uri	0	1	\N
0.12	Identifier	value	string	0	1	\N
0.12	Identifier	period	Period	0	1	\N
0.12	Identifier	assigner	ResourceReference	0	1	\N
0.12	Schedule	event	Period	0	unbounded	\N
0.12	Schedule	repeat	Schedule.Repeat	0	1	\N
0.12	Schedule.Repeat	frequency	integer	0	1	\N
0.12	Schedule.Repeat	when	EventTiming	0	1	\N
0.12	Schedule.Repeat	duration	decimal	1	1	\N
0.12	Schedule.Repeat	units	UnitsOfTime	1	1	\N
0.12	Schedule.Repeat	count	integer	0	1	\N
0.12	Schedule.Repeat	end	dateTime	0	1	\N
0.12	Contact	system	ContactSystem	0	1	\N
0.12	Contact	value	string	0	1	\N
0.12	Contact	use	ContactUse	0	1	\N
0.12	Contact	period	Period	0	1	\N
0.12	Address	use	AddressUse	0	1	\N
0.12	Address	text	string	0	1	\N
0.12	Address	line	string	0	unbounded	\N
0.12	Address	city	string	0	1	\N
0.12	Address	state	string	0	1	\N
0.12	Address	zip	string	0	1	\N
0.12	Address	country	string	0	1	\N
0.12	Address	period	Period	0	1	\N
0.12	HumanName	use	NameUse	0	1	\N
0.12	HumanName	text	string	0	1	\N
0.12	HumanName	family	string	0	unbounded	\N
0.12	HumanName	given	string	0	unbounded	\N
0.12	HumanName	prefix	string	0	unbounded	\N
0.12	HumanName	suffix	string	0	unbounded	\N
0.12	HumanName	period	Period	0	1	\N
\.


--
-- Data for Name: datatype_enums; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY datatype_enums (version, datatype, value, documentation) FROM stdin;
0.12	ResourceType	Provenance	\N
0.12	ResourceType	Condition	\N
0.12	ResourceType	CarePlan	\N
0.12	ResourceType	Supply	\N
0.12	ResourceType	Device	\N
0.12	ResourceType	Query	\N
0.12	ResourceType	Order	\N
0.12	ResourceType	Organization	\N
0.12	ResourceType	Procedure	\N
0.12	ResourceType	Substance	\N
0.12	ResourceType	DiagnosticReport	\N
0.12	ResourceType	Group	\N
0.12	ResourceType	ValueSet	\N
0.12	ResourceType	Medication	\N
0.12	ResourceType	MessageHeader	\N
0.12	ResourceType	ImmunizationRecommendation	\N
0.12	ResourceType	DocumentManifest	\N
0.12	ResourceType	MedicationDispense	\N
0.12	ResourceType	MedicationPrescription	\N
0.12	ResourceType	MedicationAdministration	\N
0.12	ResourceType	Encounter	\N
0.12	ResourceType	SecurityEvent	\N
0.12	ResourceType	MedicationStatement	\N
0.12	ResourceType	List	\N
0.12	ResourceType	Questionnaire	\N
0.12	ResourceType	Composition	\N
0.12	ResourceType	DeviceObservationReport	\N
0.12	ResourceType	OperationOutcome	\N
0.12	ResourceType	Conformance	\N
0.12	ResourceType	Media	\N
0.12	ResourceType	FamilyHistory	\N
0.12	ResourceType	Other	\N
0.12	ResourceType	Profile	\N
0.12	ResourceType	Location	\N
0.12	ResourceType	Observation	\N
0.12	ResourceType	AllergyIntolerance	\N
0.12	ResourceType	DocumentReference	\N
0.12	ResourceType	Immunization	\N
0.12	ResourceType	RelatedPerson	\N
0.12	ResourceType	Specimen	\N
0.12	ResourceType	OrderResponse	\N
0.12	ResourceType	Alert	\N
0.12	ResourceType	ConceptMap	\N
0.12	ResourceType	Patient	\N
0.12	ResourceType	Practitioner	\N
0.12	ResourceType	AdverseReaction	\N
0.12	ResourceType	ImagingStudy	\N
0.12	ResourceType	DiagnosticOrder	\N
0.12	NarrativeStatus-list	generated	\N
0.12	NarrativeStatus-list	extensions	\N
0.12	NarrativeStatus-list	additional	\N
0.12	NarrativeStatus-list	empty	\N
0.12	QuantityCompararator-list	&lt;	\N
0.12	QuantityCompararator-list	&lt;=	\N
0.12	QuantityCompararator-list	&gt;=	\N
0.12	QuantityCompararator-list	&gt;	\N
0.12	IdentifierUse-list	usual	\N
0.12	IdentifierUse-list	official	\N
0.12	IdentifierUse-list	temp	\N
0.12	IdentifierUse-list	secondary	\N
0.12	EventTiming-list	HS	\N
0.12	EventTiming-list	WAKE	\N
0.12	EventTiming-list	AC	\N
0.12	EventTiming-list	ACM	\N
0.12	EventTiming-list	ACD	\N
0.12	EventTiming-list	ACV	\N
0.12	EventTiming-list	PC	\N
0.12	EventTiming-list	PCM	\N
0.12	EventTiming-list	PCD	\N
0.12	EventTiming-list	PCV	\N
0.12	UnitsOfTime-list	s	\N
0.12	UnitsOfTime-list	min	\N
0.12	UnitsOfTime-list	h	\N
0.12	UnitsOfTime-list	d	\N
0.12	UnitsOfTime-list	wk	\N
0.12	UnitsOfTime-list	mo	\N
0.12	UnitsOfTime-list	a	\N
0.12	ContactSystem-list	phone	\N
0.12	ContactSystem-list	fax	\N
0.12	ContactSystem-list	email	\N
0.12	ContactSystem-list	url	\N
0.12	ContactUse-list	home	\N
0.12	ContactUse-list	work	\N
0.12	ContactUse-list	temp	\N
0.12	ContactUse-list	old	\N
0.12	ContactUse-list	mobile	\N
0.12	AddressUse-list	home	\N
0.12	AddressUse-list	work	\N
0.12	AddressUse-list	temp	\N
0.12	AddressUse-list	old	\N
0.12	NameUse-list	usual	\N
0.12	NameUse-list	official	\N
0.12	NameUse-list	temp	\N
0.12	NameUse-list	nickname	\N
0.12	NameUse-list	anonymous	\N
0.12	NameUse-list	old	\N
0.12	NameUse-list	maiden	\N
0.12	DocumentReferenceStatus-list	current	\N
0.12	DocumentReferenceStatus-list	superceded	\N
0.12	DocumentReferenceStatus-list	entered in error	\N
0.12	SearchParamType-list	number	\N
0.12	SearchParamType-list	date	\N
0.12	SearchParamType-list	string	\N
0.12	SearchParamType-list	token	\N
0.12	SearchParamType-list	reference	\N
0.12	SearchParamType-list	composite	\N
0.12	SearchParamType-list	quantity	\N
0.12	ValueSetStatus-list	draft	\N
0.12	ValueSetStatus-list	active	\N
0.12	ValueSetStatus-list	retired	\N
\.


--
-- Data for Name: datatypes; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY datatypes (version, type, kind, extension, restriction_base, documentation) FROM stdin;
0.12	date	\N	\N	\N	\N
0.12	id-primitive	\N	\N	\N	\N
0.12	ResourceReference	\N	\N	\N	\N
0.12	instant-primitive	\N	\N	\N	\N
0.12	string	\N	\N	\N	\N
0.12	Schedule	\N	\N	\N	\N
0.12	BackboneElement	\N	\N	\N	\N
0.12	ResourceType	\N	\N	\N	\N
0.12	Resource.Inline	\N	\N	\N	\N
0.12	integer	\N	\N	\N	\N
0.12	Coding	\N	\N	\N	\N
0.12	Age	\N	\N	\N	\N
0.12	uuid	\N	\N	\N	\N
0.12	code-primitive	\N	\N	\N	\N
0.12	SampledDataDataType-primitive	\N	\N	\N	\N
0.12	boolean	\N	\N	\N	\N
0.12	Duration	\N	\N	\N	\N
0.12	AddressUse	\N	\N	\N	\N
0.12	IdentifierUse-list	\N	\N	\N	\N
0.12	NarrativeStatus-list	\N	\N	\N	\N
0.12	SearchParamType-list	\N	\N	\N	\N
0.12	oid-primitive	\N	\N	\N	\N
0.12	oid	\N	\N	\N	\N
0.12	SearchParamType	\N	\N	\N	\N
0.12	ValueSetStatus-list	\N	\N	\N	\N
0.12	uri-primitive	\N	\N	\N	\N
0.12	QuantityCompararator-list	\N	\N	\N	\N
0.12	Money	\N	\N	\N	\N
0.12	Distance	\N	\N	\N	\N
0.12	HumanName	\N	\N	\N	\N
0.12	QuantityCompararator	\N	\N	\N	\N
0.12	id	\N	\N	\N	\N
0.12	ContactSystem-list	\N	\N	\N	\N
0.12	ContactUse	\N	\N	\N	\N
0.12	dateTime	\N	\N	\N	\N
0.12	Quantity	\N	\N	\N	\N
0.12	base64Binary-primitive	\N	\N	\N	\N
0.12	UnitsOfTime	\N	\N	\N	\N
0.12	EventTiming	\N	\N	\N	\N
0.12	Identifier	\N	\N	\N	\N
0.12	code	\N	\N	\N	\N
0.12	xmlIdRef	\N	\N	\N	\N
0.12	Element	\N	\N	\N	\N
0.12	SampledData	\N	\N	\N	\N
0.12	Range	\N	\N	\N	\N
0.12	ContactUse-list	\N	\N	\N	\N
0.12	SampledDataDataType	\N	\N	\N	\N
0.12	Count	\N	\N	\N	\N
0.12	dateTime-primitive	\N	\N	\N	\N
0.12	UnitsOfTime-list	\N	\N	\N	\N
0.12	Address	\N	\N	\N	\N
0.12	NameUse	\N	\N	\N	\N
0.12	Schedule.Repeat	\N	\N	\N	\N
0.12	Extension	\N	\N	\N	\N
0.12	decimal-primitive	\N	\N	\N	\N
0.12	ContactSystem	\N	\N	\N	\N
0.12	instant	\N	\N	\N	\N
0.12	EventTiming-list	\N	\N	\N	\N
0.12	IdentifierUse	\N	\N	\N	\N
0.12	AddressUse-list	\N	\N	\N	\N
0.12	ValueSetStatus	\N	\N	\N	\N
0.12	base64Binary	\N	\N	\N	\N
0.12	DocumentReferenceStatus	\N	\N	\N	\N
0.12	Contact	\N	\N	\N	\N
0.12	date-primitive	\N	\N	\N	\N
0.12	integer-primitive	\N	\N	\N	\N
0.12	NarrativeStatus	\N	\N	\N	\N
0.12	Narrative	\N	\N	\N	\N
0.12	Ratio	\N	\N	\N	\N
0.12	Resource	\N	\N	\N	\N
0.12	Period	\N	\N	\N	\N
0.12	NameUse-list	\N	\N	\N	\N
0.12	DocumentReferenceStatus-list	\N	\N	\N	\N
0.12	uuid-primitive	\N	\N	\N	\N
0.12	decimal	\N	\N	\N	\N
0.12	uri	\N	\N	\N	\N
0.12	boolean-primitive	\N	\N	\N	\N
0.12	string-primitive	\N	\N	\N	\N
0.12	Attachment	\N	\N	\N	\N
0.12	CodeableConcept	\N	\N	\N	\N
\.


--
-- Data for Name: hardcoded_complex_params; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY hardcoded_complex_params (path, type) FROM stdin;
{ConceptMap,concept,map,product,concept}	uri
{DiagnosticOrder,item,event,dateTime}	dataTime
{DiagnosticOrder,item,event,status}	code
{Patient,name,family}	string
{Patient,name,given}	string
{Provenance,period,end}	dateTime
{Provenance,period,start}	dataTime
\.


--
-- Data for Name: resource_elements; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY resource_elements (version, path, min, max, type, ref_type) FROM stdin;
0.12	{ValueSet}	1	1	{Resource}	\N
0.12	{ValueSet,extension}	0	*	{Extension}	\N
0.12	{ValueSet,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,text}	0	1	{Narrative}	\N
0.12	{ValueSet,contained}	0	*	{Resource}	\N
0.12	{ValueSet,identifier}	0	1	{string}	\N
0.12	{ValueSet,version}	0	1	{string}	\N
0.12	{ValueSet,name}	1	1	{string}	\N
0.12	{ValueSet,publisher}	0	1	{string}	\N
0.12	{ValueSet,telecom}	0	*	{Contact}	\N
0.12	{ValueSet,description}	1	1	{string}	\N
0.12	{ValueSet,copyright}	0	1	{string}	\N
0.12	{ValueSet,status}	1	1	{code}	\N
0.12	{ValueSet,experimental}	0	1	{boolean}	\N
0.12	{ValueSet,extensible}	0	1	{boolean}	\N
0.12	{ValueSet,date}	0	1	{dateTime}	\N
0.12	{ValueSet,define}	0	1	{}	\N
0.12	{ValueSet,define,extension}	0	*	{Extension}	\N
0.12	{ValueSet,define,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,define,system}	1	1	{uri}	\N
0.12	{ValueSet,define,version}	0	1	{string}	\N
0.12	{ValueSet,define,caseSensitive}	0	1	{boolean}	\N
0.12	{ValueSet,define,concept}	0	*	{}	\N
0.12	{ValueSet,define,concept,extension}	0	*	{Extension}	\N
0.12	{ValueSet,define,concept,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,define,concept,code}	1	1	{code}	\N
0.12	{ValueSet,define,concept,abstract}	0	1	{boolean}	\N
0.12	{ValueSet,define,concept,display}	0	1	{string}	\N
0.12	{ValueSet,define,concept,definition}	0	1	{string}	\N
0.12	{ValueSet,define,concept,concept}	0	*	{}	\N
0.12	{ValueSet,compose}	0	1	{}	\N
0.12	{ValueSet,compose,extension}	0	*	{Extension}	\N
0.12	{ValueSet,compose,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,compose,import}	0	*	{uri}	\N
0.12	{ValueSet,compose,include}	0	*	{}	\N
0.12	{ValueSet,compose,include,extension}	0	*	{Extension}	\N
0.12	{ValueSet,compose,include,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,compose,include,system}	1	1	{uri}	\N
0.12	{ValueSet,compose,include,version}	0	1	{string}	\N
0.12	{ValueSet,compose,include,code}	0	*	{code}	\N
0.12	{ValueSet,compose,include,filter}	0	*	{}	\N
0.12	{ValueSet,compose,include,filter,extension}	0	*	{Extension}	\N
0.12	{ValueSet,compose,include,filter,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,compose,include,filter,property}	1	1	{code}	\N
0.12	{ValueSet,compose,include,filter,op}	1	1	{code}	\N
0.12	{ValueSet,compose,include,filter,value}	1	1	{code}	\N
0.12	{ValueSet,compose,exclude}	0	*	{}	\N
0.12	{ValueSet,expansion}	0	1	{}	\N
0.12	{ValueSet,expansion,extension}	0	*	{Extension}	\N
0.12	{ValueSet,expansion,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,expansion,identifier}	0	1	{Identifier}	\N
0.12	{ValueSet,expansion,timestamp}	1	1	{instant}	\N
0.12	{ValueSet,expansion,contains}	0	*	{}	\N
0.12	{ValueSet,expansion,contains,extension}	0	*	{Extension}	\N
0.12	{ValueSet,expansion,contains,modifierExtension}	0	*	{Extension}	\N
0.12	{ValueSet,expansion,contains,system}	0	1	{uri}	\N
0.12	{ValueSet,expansion,contains,code}	0	1	{code}	\N
0.12	{ValueSet,expansion,contains,display}	0	1	{string}	\N
0.12	{ValueSet,expansion,contains,contains}	0	*	{}	\N
0.12	{AdverseReaction}	1	1	{Resource}	\N
0.12	{AdverseReaction,extension}	0	*	{Extension}	\N
0.12	{AdverseReaction,modifierExtension}	0	*	{Extension}	\N
0.12	{AdverseReaction,text}	0	1	{Narrative}	\N
0.12	{AdverseReaction,contained}	0	*	{Resource}	\N
0.12	{AdverseReaction,identifier}	0	*	{Identifier}	\N
0.12	{AdverseReaction,date}	0	1	{dateTime}	\N
0.12	{AdverseReaction,subject}	1	1	{ResourceReference}	{Patient}
0.12	{AdverseReaction,didNotOccurFlag}	1	1	{boolean}	\N
0.12	{AdverseReaction,recorder}	0	1	{ResourceReference,ResourceReference}	{Practitioner,Patient}
0.12	{AdverseReaction,symptom}	0	*	{}	\N
0.12	{AdverseReaction,symptom,extension}	0	*	{Extension}	\N
0.12	{AdverseReaction,symptom,modifierExtension}	0	*	{Extension}	\N
0.12	{AdverseReaction,symptom,code}	1	1	{CodeableConcept}	\N
0.12	{AdverseReaction,symptom,severity}	0	1	{code}	\N
0.12	{AdverseReaction,exposure}	0	*	{}	\N
0.12	{AdverseReaction,exposure,extension}	0	*	{Extension}	\N
0.12	{AdverseReaction,exposure,modifierExtension}	0	*	{Extension}	\N
0.12	{AdverseReaction,exposure,date}	0	1	{dateTime}	\N
0.12	{AdverseReaction,exposure,type}	0	1	{code}	\N
0.12	{AdverseReaction,exposure,causalityExpectation}	0	1	{code}	\N
0.12	{AdverseReaction,exposure,substance}	0	1	{ResourceReference}	{Substance}
0.12	{Alert}	1	1	{Resource}	\N
0.12	{Alert,extension}	0	*	{Extension}	\N
0.12	{Alert,modifierExtension}	0	*	{Extension}	\N
0.12	{Alert,text}	0	1	{Narrative}	\N
0.12	{Alert,contained}	0	*	{Resource}	\N
0.12	{Alert,identifier}	0	*	{Identifier}	\N
0.12	{Alert,category}	0	1	{CodeableConcept}	\N
0.12	{Alert,status}	1	1	{code}	\N
0.12	{Alert,subject}	1	1	{ResourceReference}	{Patient}
0.12	{Alert,author}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Patient,Device}
0.12	{Alert,note}	1	1	{string}	\N
0.12	{AllergyIntolerance}	1	1	{Resource}	\N
0.12	{AllergyIntolerance,extension}	0	*	{Extension}	\N
0.12	{AllergyIntolerance,modifierExtension}	0	*	{Extension}	\N
0.12	{AllergyIntolerance,text}	0	1	{Narrative}	\N
0.12	{AllergyIntolerance,contained}	0	*	{Resource}	\N
0.12	{AllergyIntolerance,identifier}	0	*	{Identifier}	\N
0.12	{AllergyIntolerance,criticality}	0	1	{code}	\N
0.12	{AllergyIntolerance,sensitivityType}	1	1	{code}	\N
0.12	{AllergyIntolerance,recordedDate}	0	1	{dateTime}	\N
0.12	{AllergyIntolerance,status}	1	1	{code}	\N
0.12	{AllergyIntolerance,subject}	1	1	{ResourceReference}	{Patient}
0.12	{AllergyIntolerance,recorder}	0	1	{ResourceReference,ResourceReference}	{Practitioner,Patient}
0.12	{AllergyIntolerance,substance}	1	1	{ResourceReference}	{Substance}
0.12	{AllergyIntolerance,reaction}	0	*	{ResourceReference}	{AdverseReaction}
0.12	{AllergyIntolerance,sensitivityTest}	0	*	{ResourceReference}	{Observation}
0.12	{CarePlan}	1	1	{Resource}	\N
0.12	{CarePlan,extension}	0	*	{Extension}	\N
0.12	{CarePlan,modifierExtension}	0	*	{Extension}	\N
0.12	{CarePlan,text}	0	1	{Narrative}	\N
0.12	{CarePlan,contained}	0	*	{Resource}	\N
0.12	{CarePlan,identifier}	0	*	{Identifier}	\N
0.12	{CarePlan,patient}	0	1	{ResourceReference}	{Patient}
0.12	{CarePlan,status}	1	1	{code}	\N
0.12	{CarePlan,period}	0	1	{Period}	\N
0.12	{CarePlan,modified}	0	1	{dateTime}	\N
0.12	{CarePlan,concern}	0	*	{ResourceReference}	{Condition}
0.12	{CarePlan,participant}	0	*	{}	\N
0.12	{CarePlan,participant,extension}	0	*	{Extension}	\N
0.12	{CarePlan,participant,modifierExtension}	0	*	{Extension}	\N
0.12	{CarePlan,participant,role}	0	1	{CodeableConcept}	\N
0.12	{CarePlan,participant,member}	1	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Practitioner,RelatedPerson,Patient,Organization}
0.12	{CarePlan,goal}	0	*	{}	\N
0.12	{CarePlan,goal,extension}	0	*	{Extension}	\N
0.12	{CarePlan,goal,modifierExtension}	0	*	{Extension}	\N
0.12	{CarePlan,goal,description}	1	1	{string}	\N
0.12	{CarePlan,goal,status}	0	1	{code}	\N
0.12	{CarePlan,goal,notes}	0	1	{string}	\N
0.12	{CarePlan,goal,concern}	0	*	{ResourceReference}	{Condition}
0.12	{CarePlan,activity}	0	*	{}	\N
0.12	{CarePlan,activity,extension}	0	*	{Extension}	\N
0.12	{CarePlan,activity,modifierExtension}	0	*	{Extension}	\N
0.12	{CarePlan,activity,goal}	0	*	{idref}	\N
0.12	{CarePlan,activity,status}	0	1	{code}	\N
0.12	{CarePlan,activity,prohibited}	1	1	{boolean}	\N
0.12	{CarePlan,activity,actionResulting}	0	*	{ResourceReference}	{Any}
0.12	{CarePlan,activity,notes}	0	1	{string}	\N
0.12	{CarePlan,activity,detail}	0	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Procedure,MedicationPrescription,DiagnosticOrder,Encounter}
0.12	{CarePlan,activity,simple}	0	1	{}	\N
0.12	{CarePlan,activity,simple,extension}	0	*	{Extension}	\N
0.12	{CarePlan,activity,simple,modifierExtension}	0	*	{Extension}	\N
0.12	{CarePlan,activity,simple,category}	1	1	{code}	\N
0.12	{CarePlan,activity,simple,code}	0	1	{CodeableConcept}	\N
0.12	{CarePlan,activity,simple,timing[x]}	0	1	{Schedule,Period,string}	\N
0.12	{CarePlan,activity,simple,location}	0	1	{ResourceReference}	{Location}
0.12	{CarePlan,activity,simple,performer}	0	*	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Organization,RelatedPerson,Patient}
0.12	{CarePlan,activity,simple,product}	0	1	{ResourceReference,ResourceReference}	{Medication,Substance}
0.12	{CarePlan,activity,simple,dailyAmount}	0	1	{Quantity}	\N
0.12	{CarePlan,activity,simple,quantity}	0	1	{Quantity}	\N
0.12	{CarePlan,activity,simple,details}	0	1	{string}	\N
0.12	{CarePlan,notes}	0	1	{string}	\N
0.12	{Composition}	1	1	{Resource}	\N
0.12	{Composition,extension}	0	*	{Extension}	\N
0.12	{Composition,modifierExtension}	0	*	{Extension}	\N
0.12	{Composition,text}	0	1	{Narrative}	\N
0.12	{Composition,contained}	0	*	{Resource}	\N
0.12	{Composition,identifier}	0	1	{Identifier}	\N
0.12	{Composition,date}	1	1	{dateTime}	\N
0.12	{Composition,type}	1	1	{CodeableConcept}	\N
0.12	{Composition,class}	0	1	{CodeableConcept}	\N
0.12	{Composition,title}	0	1	{string}	\N
0.12	{Composition,status}	1	1	{code}	\N
0.12	{Composition,confidentiality}	1	1	{Coding}	\N
0.12	{Composition,subject}	1	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,Group,Device,Location}
0.12	{Composition,author}	1	*	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Device,Patient,RelatedPerson}
0.12	{Composition,attester}	0	*	{}	\N
0.12	{Composition,attester,extension}	0	*	{Extension}	\N
0.12	{Composition,attester,modifierExtension}	0	*	{Extension}	\N
0.12	{Composition,attester,mode}	1	*	{code}	\N
0.12	{Composition,attester,time}	0	1	{dateTime}	\N
0.12	{Condition,identifier}	0	*	{Identifier}	\N
0.12	{Composition,attester,party}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,Organization}
0.12	{Composition,custodian}	0	1	{ResourceReference}	{Organization}
0.12	{Composition,event}	0	1	{}	\N
0.12	{Composition,event,extension}	0	*	{Extension}	\N
0.12	{Composition,event,modifierExtension}	0	*	{Extension}	\N
0.12	{Composition,event,code}	0	*	{CodeableConcept}	\N
0.12	{Composition,event,period}	0	1	{Period}	\N
0.12	{Composition,event,detail}	0	*	{ResourceReference}	{Any}
0.12	{Composition,encounter}	0	1	{ResourceReference}	{Encounter}
0.12	{Composition,section}	0	*	{}	\N
0.12	{Composition,section,extension}	0	*	{Extension}	\N
0.12	{Composition,section,modifierExtension}	0	*	{Extension}	\N
0.12	{Composition,section,title}	0	1	{string}	\N
0.12	{Composition,section,code}	0	1	{CodeableConcept}	\N
0.12	{Composition,section,subject}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Patient,Group,Device}
0.12	{Composition,section,content}	0	1	{ResourceReference}	{Any}
0.12	{Composition,section,section}	0	*	{}	\N
0.12	{ConceptMap}	1	1	{Resource}	\N
0.12	{ConceptMap,extension}	0	*	{Extension}	\N
0.12	{ConceptMap,modifierExtension}	0	*	{Extension}	\N
0.12	{ConceptMap,text}	0	1	{Narrative}	\N
0.12	{ConceptMap,contained}	0	*	{Resource}	\N
0.12	{ConceptMap,identifier}	0	1	{string}	\N
0.12	{ConceptMap,version}	0	1	{string}	\N
0.12	{ConceptMap,name}	1	1	{string}	\N
0.12	{ConceptMap,publisher}	0	1	{string}	\N
0.12	{ConceptMap,telecom}	0	*	{Contact}	\N
0.12	{ConceptMap,description}	0	1	{string}	\N
0.12	{ConceptMap,copyright}	0	1	{string}	\N
0.12	{ConceptMap,status}	1	1	{code}	\N
0.12	{ConceptMap,experimental}	0	1	{boolean}	\N
0.12	{ConceptMap,date}	0	1	{dateTime}	\N
0.12	{ConceptMap,source}	1	1	{ResourceReference}	{ValueSet}
0.12	{ConceptMap,target}	1	1	{ResourceReference}	{ValueSet}
0.12	{ConceptMap,concept}	0	*	{}	\N
0.12	{ConceptMap,concept,extension}	0	*	{Extension}	\N
0.12	{ConceptMap,concept,modifierExtension}	0	*	{Extension}	\N
0.12	{ConceptMap,concept,system}	1	1	{uri}	\N
0.12	{ConceptMap,concept,code}	0	1	{code}	\N
0.12	{ConceptMap,concept,dependsOn}	0	*	{}	\N
0.12	{ConceptMap,concept,dependsOn,extension}	0	*	{Extension}	\N
0.12	{ConceptMap,concept,dependsOn,modifierExtension}	0	*	{Extension}	\N
0.12	{ConceptMap,concept,dependsOn,concept}	1	1	{uri}	\N
0.12	{ConceptMap,concept,dependsOn,system}	1	1	{uri}	\N
0.12	{ConceptMap,concept,dependsOn,code}	1	1	{code}	\N
0.12	{ConceptMap,concept,map}	0	*	{}	\N
0.12	{ConceptMap,concept,map,extension}	0	*	{Extension}	\N
0.12	{ConceptMap,concept,map,modifierExtension}	0	*	{Extension}	\N
0.12	{ConceptMap,concept,map,system}	0	1	{uri}	\N
0.12	{ConceptMap,concept,map,code}	0	1	{code}	\N
0.12	{ConceptMap,concept,map,equivalence}	1	1	{code}	\N
0.12	{ConceptMap,concept,map,comments}	0	1	{string}	\N
0.12	{ConceptMap,concept,map,product}	0	*	{}	\N
0.12	{Condition}	1	1	{Resource}	\N
0.12	{Condition,extension}	0	*	{Extension}	\N
0.12	{Condition,modifierExtension}	0	*	{Extension}	\N
0.12	{Condition,text}	0	1	{Narrative}	\N
0.12	{Condition,contained}	0	*	{Resource}	\N
0.12	{Condition,subject}	1	1	{ResourceReference}	{Patient}
0.12	{Condition,encounter}	0	1	{ResourceReference}	{Encounter}
0.12	{Condition,asserter}	0	1	{ResourceReference,ResourceReference}	{Practitioner,Patient}
0.12	{Condition,dateAsserted}	0	1	{date}	\N
0.12	{Condition,code}	1	1	{CodeableConcept}	\N
0.12	{Condition,category}	0	1	{CodeableConcept}	\N
0.12	{Condition,status}	1	1	{code}	\N
0.12	{Condition,certainty}	0	1	{CodeableConcept}	\N
0.12	{Condition,severity}	0	1	{CodeableConcept}	\N
0.12	{Condition,onset[x]}	0	1	{date,Age}	\N
0.12	{Condition,abatement[x]}	0	1	{date,Age,boolean}	\N
0.12	{Condition,stage}	0	1	{}	\N
0.12	{Condition,stage,extension}	0	*	{Extension}	\N
0.12	{Condition,stage,modifierExtension}	0	*	{Extension}	\N
0.12	{Condition,stage,summary}	0	1	{CodeableConcept}	\N
0.12	{Condition,stage,assessment}	0	*	{ResourceReference}	{Any}
0.12	{Condition,evidence}	0	*	{}	\N
0.12	{Condition,evidence,extension}	0	*	{Extension}	\N
0.12	{Condition,evidence,modifierExtension}	0	*	{Extension}	\N
0.12	{Condition,evidence,code}	0	1	{CodeableConcept}	\N
0.12	{Condition,evidence,detail}	0	*	{ResourceReference}	{Any}
0.12	{Condition,location}	0	*	{}	\N
0.12	{Condition,location,extension}	0	*	{Extension}	\N
0.12	{Condition,location,modifierExtension}	0	*	{Extension}	\N
0.12	{Condition,location,code}	0	1	{CodeableConcept}	\N
0.12	{Condition,location,detail}	0	1	{string}	\N
0.12	{Condition,relatedItem}	0	*	{}	\N
0.12	{Condition,relatedItem,extension}	0	*	{Extension}	\N
0.12	{Condition,relatedItem,modifierExtension}	0	*	{Extension}	\N
0.12	{Condition,relatedItem,type}	1	1	{code}	\N
0.12	{Condition,relatedItem,code}	0	1	{CodeableConcept}	\N
0.12	{Condition,relatedItem,target}	0	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Condition,Procedure,MedicationAdministration,Immunization,MedicationStatement}
0.12	{Condition,notes}	0	1	{string}	\N
0.12	{Conformance}	1	1	{Resource}	\N
0.12	{Conformance,extension}	0	*	{Extension}	\N
0.12	{Conformance,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,text}	0	1	{Narrative}	\N
0.12	{Conformance,contained}	0	*	{Resource}	\N
0.12	{Conformance,identifier}	0	1	{string}	\N
0.12	{Conformance,version}	0	1	{string}	\N
0.12	{Conformance,name}	0	1	{string}	\N
0.12	{Conformance,publisher}	1	1	{string}	\N
0.12	{Conformance,telecom}	0	*	{Contact}	\N
0.12	{Conformance,description}	0	1	{string}	\N
0.12	{Conformance,status}	0	1	{code}	\N
0.12	{Conformance,experimental}	0	1	{boolean}	\N
0.12	{Conformance,date}	1	1	{dateTime}	\N
0.12	{Conformance,software}	0	1	{}	\N
0.12	{Conformance,software,extension}	0	*	{Extension}	\N
0.12	{Conformance,software,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,software,name}	1	1	{string}	\N
0.12	{Conformance,software,version}	0	1	{string}	\N
0.12	{Conformance,software,releaseDate}	0	1	{dateTime}	\N
0.12	{Conformance,implementation}	0	1	{}	\N
0.12	{Conformance,implementation,extension}	0	*	{Extension}	\N
0.12	{Conformance,implementation,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,implementation,description}	1	1	{string}	\N
0.12	{Conformance,implementation,url}	0	1	{uri}	\N
0.12	{Conformance,fhirVersion}	1	1	{id}	\N
0.12	{Conformance,acceptUnknown}	1	1	{boolean}	\N
0.12	{Conformance,format}	1	*	{code}	\N
0.12	{Conformance,profile}	0	*	{ResourceReference}	{Profile}
0.12	{Conformance,rest}	0	*	{}	\N
0.12	{Conformance,rest,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,mode}	1	1	{code}	\N
0.12	{Conformance,rest,documentation}	0	1	{string}	\N
0.12	{Conformance,rest,security}	0	1	{}	\N
0.12	{Conformance,rest,security,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,security,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,security,cors}	0	1	{boolean}	\N
0.12	{Conformance,rest,security,service}	0	*	{CodeableConcept}	\N
0.12	{Conformance,rest,security,description}	0	1	{string}	\N
0.12	{Conformance,rest,security,certificate}	0	*	{}	\N
0.12	{Conformance,rest,security,certificate,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,security,certificate,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,security,certificate,type}	0	1	{code}	\N
0.12	{Conformance,rest,security,certificate,blob}	0	1	{base64Binary}	\N
0.12	{Conformance,rest,resource}	1	*	{}	\N
0.12	{Conformance,rest,resource,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,resource,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,resource,type}	1	1	{code}	\N
0.12	{Conformance,rest,resource,profile}	0	1	{ResourceReference}	{Profile}
0.12	{Conformance,rest,resource,operation}	1	*	{}	\N
0.12	{Conformance,rest,resource,operation,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,resource,operation,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,resource,operation,code}	1	1	{code}	\N
0.12	{Conformance,rest,resource,operation,documentation}	0	1	{string}	\N
0.12	{Conformance,rest,resource,readHistory}	0	1	{boolean}	\N
0.12	{Conformance,rest,resource,updateCreate}	0	1	{boolean}	\N
0.12	{Conformance,rest,resource,searchInclude}	0	*	{string}	\N
0.12	{Conformance,rest,resource,searchParam}	0	*	{}	\N
0.12	{Conformance,rest,resource,searchParam,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,resource,searchParam,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,resource,searchParam,name}	1	1	{string}	\N
0.12	{Conformance,rest,resource,searchParam,definition}	0	1	{uri}	\N
0.12	{Conformance,rest,resource,searchParam,type}	1	1	{code}	\N
0.12	{Conformance,rest,resource,searchParam,documentation}	0	1	{string}	\N
0.12	{Conformance,rest,resource,searchParam,target}	0	*	{code}	\N
0.12	{Conformance,rest,resource,searchParam,chain}	0	*	{string}	\N
0.12	{Conformance,rest,operation}	0	*	{}	\N
0.12	{Conformance,rest,operation,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,operation,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,operation,code}	1	1	{code}	\N
0.12	{Conformance,rest,operation,documentation}	0	1	{string}	\N
0.12	{Conformance,rest,query}	0	*	{}	\N
0.12	{Conformance,rest,query,extension}	0	*	{Extension}	\N
0.12	{Conformance,rest,query,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,rest,query,name}	1	1	{string}	\N
0.12	{Conformance,rest,query,definition}	1	1	{uri}	\N
0.12	{Conformance,rest,query,documentation}	0	1	{string}	\N
0.12	{Conformance,rest,query,parameter}	0	*	{}	\N
0.12	{Conformance,rest,documentMailbox}	0	*	{uri}	\N
0.12	{Conformance,messaging}	0	*	{}	\N
0.12	{Conformance,messaging,extension}	0	*	{Extension}	\N
0.12	{Conformance,messaging,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,messaging,endpoint}	0	1	{uri}	\N
0.12	{Conformance,messaging,reliableCache}	0	1	{integer}	\N
0.12	{Conformance,messaging,documentation}	0	1	{string}	\N
0.12	{Conformance,messaging,event}	1	*	{}	\N
0.12	{Conformance,messaging,event,extension}	0	*	{Extension}	\N
0.12	{Conformance,messaging,event,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,messaging,event,code}	1	1	{Coding}	\N
0.12	{Conformance,messaging,event,category}	0	1	{code}	\N
0.12	{Conformance,messaging,event,mode}	1	1	{code}	\N
0.12	{Conformance,messaging,event,protocol}	0	*	{Coding}	\N
0.12	{Conformance,messaging,event,focus}	1	1	{code}	\N
0.12	{Conformance,messaging,event,request}	1	1	{ResourceReference}	{Profile}
0.12	{Conformance,messaging,event,response}	1	1	{ResourceReference}	{Profile}
0.12	{Conformance,messaging,event,documentation}	0	1	{string}	\N
0.12	{Conformance,document}	0	*	{}	\N
0.12	{Conformance,document,extension}	0	*	{Extension}	\N
0.12	{Conformance,document,modifierExtension}	0	*	{Extension}	\N
0.12	{Conformance,document,mode}	1	1	{code}	\N
0.12	{Conformance,document,documentation}	0	1	{string}	\N
0.12	{Conformance,document,profile}	1	1	{ResourceReference}	{Profile}
0.12	{Device}	1	1	{Resource}	\N
0.12	{Device,extension}	0	*	{Extension}	\N
0.12	{Device,modifierExtension}	0	*	{Extension}	\N
0.12	{Device,text}	0	1	{Narrative}	\N
0.12	{Device,contained}	0	*	{Resource}	\N
0.12	{Device,identifier}	0	*	{Identifier}	\N
0.12	{Device,type}	1	1	{CodeableConcept}	\N
0.12	{Device,manufacturer}	0	1	{string}	\N
0.12	{Device,model}	0	1	{string}	\N
0.12	{Device,version}	0	1	{string}	\N
0.12	{Device,expiry}	0	1	{date}	\N
0.12	{Device,udi}	0	1	{string}	\N
0.12	{Device,lotNumber}	0	1	{string}	\N
0.12	{Device,owner}	0	1	{ResourceReference}	{Organization}
0.12	{Device,location}	0	1	{ResourceReference}	{Location}
0.12	{Device,patient}	0	1	{ResourceReference}	{Patient}
0.12	{Device,contact}	0	*	{Contact}	\N
0.12	{Device,url}	0	1	{uri}	\N
0.12	{DeviceObservationReport}	1	1	{Resource}	\N
0.12	{DeviceObservationReport,extension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,modifierExtension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,text}	0	1	{Narrative}	\N
0.12	{DeviceObservationReport,contained}	0	*	{Resource}	\N
0.12	{DeviceObservationReport,instant}	1	1	{instant}	\N
0.12	{DeviceObservationReport,identifier}	0	1	{Identifier}	\N
0.12	{DeviceObservationReport,source}	1	1	{ResourceReference}	{Device}
0.12	{DeviceObservationReport,subject}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Patient,Device,Location}
0.12	{DeviceObservationReport,virtualDevice}	0	*	{}	\N
0.12	{DeviceObservationReport,virtualDevice,extension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,virtualDevice,modifierExtension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,virtualDevice,code}	0	1	{CodeableConcept}	\N
0.12	{DeviceObservationReport,virtualDevice,channel}	0	*	{}	\N
0.12	{DeviceObservationReport,virtualDevice,channel,extension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,virtualDevice,channel,modifierExtension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,virtualDevice,channel,code}	0	1	{CodeableConcept}	\N
0.12	{DeviceObservationReport,virtualDevice,channel,metric}	0	*	{}	\N
0.12	{DeviceObservationReport,virtualDevice,channel,metric,extension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,virtualDevice,channel,metric,modifierExtension}	0	*	{Extension}	\N
0.12	{DeviceObservationReport,virtualDevice,channel,metric,observation}	1	1	{ResourceReference}	{Observation}
0.12	{DiagnosticOrder}	1	1	{Resource}	\N
0.12	{DiagnosticOrder,extension}	0	*	{Extension}	\N
0.12	{DiagnosticOrder,modifierExtension}	0	*	{Extension}	\N
0.12	{DiagnosticOrder,text}	0	1	{Narrative}	\N
0.12	{DiagnosticOrder,contained}	0	*	{Resource}	\N
0.12	{DiagnosticOrder,subject}	1	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Group,Location,Device}
0.12	{DiagnosticOrder,orderer}	0	1	{ResourceReference}	{Practitioner}
0.12	{DiagnosticOrder,identifier}	0	*	{Identifier}	\N
0.12	{DiagnosticOrder,encounter}	0	1	{ResourceReference}	{Encounter}
0.12	{DiagnosticOrder,clinicalNotes}	0	1	{string}	\N
0.12	{DiagnosticOrder,specimen}	0	*	{ResourceReference}	{Specimen}
0.12	{DiagnosticOrder,status}	0	1	{code}	\N
0.12	{DiagnosticOrder,priority}	0	1	{code}	\N
0.12	{DiagnosticOrder,event}	0	*	{}	\N
0.12	{DiagnosticOrder,event,extension}	0	*	{Extension}	\N
0.12	{DiagnosticOrder,event,modifierExtension}	0	*	{Extension}	\N
0.12	{DiagnosticOrder,event,status}	1	1	{code}	\N
0.12	{DiagnosticOrder,event,description}	0	1	{CodeableConcept}	\N
0.12	{DiagnosticOrder,event,dateTime}	1	1	{dateTime}	\N
0.12	{DiagnosticOrder,event,actor}	0	1	{ResourceReference,ResourceReference}	{Practitioner,Device}
0.12	{DiagnosticOrder,item}	0	*	{}	\N
0.12	{DiagnosticOrder,item,extension}	0	*	{Extension}	\N
0.12	{DiagnosticOrder,item,modifierExtension}	0	*	{Extension}	\N
0.12	{DiagnosticOrder,item,code}	1	1	{CodeableConcept}	\N
0.12	{DiagnosticOrder,item,specimen}	0	*	{ResourceReference}	{Specimen}
0.12	{DiagnosticOrder,item,bodySite}	0	1	{CodeableConcept}	\N
0.12	{DiagnosticOrder,item,status}	0	1	{code}	\N
0.12	{DiagnosticOrder,item,event}	0	*	{}	\N
0.12	{DiagnosticReport}	1	1	{Resource}	\N
0.12	{DiagnosticReport,extension}	0	*	{Extension}	\N
0.12	{DiagnosticReport,modifierExtension}	0	*	{Extension}	\N
0.12	{DiagnosticReport,text}	0	1	{Narrative}	\N
0.12	{DiagnosticReport,contained}	0	*	{Resource}	\N
0.12	{DiagnosticReport,name}	1	1	{CodeableConcept}	\N
0.12	{DiagnosticReport,status}	1	1	{code}	\N
0.12	{DiagnosticReport,issued}	1	1	{dateTime}	\N
0.12	{DiagnosticReport,subject}	1	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Group,Device,Location}
0.12	{DiagnosticReport,performer}	1	1	{ResourceReference,ResourceReference}	{Practitioner,Organization}
0.12	{DiagnosticReport,identifier}	0	1	{Identifier}	\N
0.12	{DiagnosticReport,requestDetail}	0	*	{ResourceReference}	{DiagnosticOrder}
0.12	{DiagnosticReport,serviceCategory}	0	1	{CodeableConcept}	\N
0.12	{DiagnosticReport,diagnostic[x]}	1	1	{dateTime,Period}	\N
0.12	{DiagnosticReport,specimen}	0	*	{ResourceReference}	{Specimen}
0.12	{DiagnosticReport,result}	0	*	{ResourceReference}	{Observation}
0.12	{DiagnosticReport,imagingStudy}	0	*	{ResourceReference}	{ImagingStudy}
0.12	{DiagnosticReport,image}	0	*	{}	\N
0.12	{DiagnosticReport,image,extension}	0	*	{Extension}	\N
0.12	{DiagnosticReport,image,modifierExtension}	0	*	{Extension}	\N
0.12	{DiagnosticReport,image,comment}	0	1	{string}	\N
0.12	{DiagnosticReport,image,link}	1	1	{ResourceReference}	{Media}
0.12	{DiagnosticReport,conclusion}	0	1	{string}	\N
0.12	{DiagnosticReport,codedDiagnosis}	0	*	{CodeableConcept}	\N
0.12	{DiagnosticReport,presentedForm}	0	*	{Attachment}	\N
0.12	{DocumentManifest}	1	1	{Resource}	\N
0.12	{DocumentManifest,extension}	0	*	{Extension}	\N
0.12	{DocumentManifest,modifierExtension}	0	*	{Extension}	\N
0.12	{DocumentManifest,text}	0	1	{Narrative}	\N
0.12	{DocumentManifest,contained}	0	*	{Resource}	\N
0.12	{DocumentManifest,masterIdentifier}	1	1	{Identifier}	\N
0.12	{DocumentManifest,identifier}	0	*	{Identifier}	\N
0.12	{DocumentManifest,subject}	1	*	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,Group,Device}
0.12	{DocumentManifest,recipient}	0	*	{ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,Organization}
0.12	{DocumentManifest,type}	0	1	{CodeableConcept}	\N
0.12	{DocumentManifest,author}	0	*	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Device,Patient,RelatedPerson}
0.12	{DocumentManifest,created}	0	1	{dateTime}	\N
0.12	{DocumentManifest,source}	0	1	{uri}	\N
0.12	{DocumentManifest,status}	1	1	{code}	\N
0.12	{DocumentManifest,supercedes}	0	1	{ResourceReference}	{DocumentManifest}
0.12	{DocumentManifest,description}	0	1	{string}	\N
0.12	{DocumentManifest,confidentiality}	0	1	{CodeableConcept}	\N
0.12	{DocumentManifest,content}	1	*	{ResourceReference,ResourceReference,ResourceReference}	{DocumentReference,Binary,Media}
0.12	{DocumentReference}	1	1	{Resource}	\N
0.12	{DocumentReference,extension}	0	*	{Extension}	\N
0.12	{DocumentReference,modifierExtension}	0	*	{Extension}	\N
0.12	{DocumentReference,text}	0	1	{Narrative}	\N
0.12	{DocumentReference,contained}	0	*	{Resource}	\N
0.12	{DocumentReference,masterIdentifier}	1	1	{Identifier}	\N
0.12	{DocumentReference,identifier}	0	*	{Identifier}	\N
0.12	{DocumentReference,subject}	1	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,Group,Device}
0.12	{DocumentReference,type}	1	1	{CodeableConcept}	\N
0.12	{DocumentReference,class}	0	1	{CodeableConcept}	\N
0.12	{DocumentReference,author}	1	*	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Device,Patient,RelatedPerson}
0.12	{DocumentReference,custodian}	0	1	{ResourceReference}	{Organization}
0.12	{DocumentReference,policyManager}	0	1	{uri}	\N
0.12	{DocumentReference,authenticator}	0	1	{ResourceReference,ResourceReference}	{Practitioner,Organization}
0.12	{DocumentReference,created}	0	1	{dateTime}	\N
0.12	{DocumentReference,indexed}	1	1	{instant}	\N
0.12	{DocumentReference,status}	1	1	{code}	\N
0.12	{DocumentReference,docStatus}	0	1	{CodeableConcept}	\N
0.12	{DocumentReference,relatesTo}	0	*	{}	\N
0.12	{DocumentReference,relatesTo,extension}	0	*	{Extension}	\N
0.12	{DocumentReference,relatesTo,modifierExtension}	0	*	{Extension}	\N
0.12	{DocumentReference,relatesTo,code}	1	1	{code}	\N
0.12	{DocumentReference,relatesTo,target}	1	1	{ResourceReference}	{DocumentReference}
0.12	{DocumentReference,description}	0	1	{string}	\N
0.12	{DocumentReference,confidentiality}	0	*	{CodeableConcept}	\N
0.12	{DocumentReference,primaryLanguage}	0	1	{code}	\N
0.12	{DocumentReference,mimeType}	1	1	{code}	\N
0.12	{DocumentReference,format}	0	*	{uri}	\N
0.12	{DocumentReference,size}	0	1	{integer}	\N
0.12	{DocumentReference,hash}	0	1	{string}	\N
0.12	{DocumentReference,location}	0	1	{uri}	\N
0.12	{DocumentReference,service}	0	1	{}	\N
0.12	{DocumentReference,service,extension}	0	*	{Extension}	\N
0.12	{DocumentReference,service,modifierExtension}	0	*	{Extension}	\N
0.12	{DocumentReference,service,type}	1	1	{CodeableConcept}	\N
0.12	{DocumentReference,service,address}	0	1	{string}	\N
0.12	{DocumentReference,service,parameter}	0	*	{}	\N
0.12	{DocumentReference,service,parameter,extension}	0	*	{Extension}	\N
0.12	{DocumentReference,service,parameter,modifierExtension}	0	*	{Extension}	\N
0.12	{DocumentReference,service,parameter,name}	1	1	{string}	\N
0.12	{DocumentReference,service,parameter,value}	0	1	{string}	\N
0.12	{DocumentReference,context}	0	1	{}	\N
0.12	{DocumentReference,context,extension}	0	*	{Extension}	\N
0.12	{DocumentReference,context,modifierExtension}	0	*	{Extension}	\N
0.12	{DocumentReference,context,event}	0	*	{CodeableConcept}	\N
0.12	{DocumentReference,context,period}	0	1	{Period}	\N
0.12	{DocumentReference,context,facilityType}	0	1	{CodeableConcept}	\N
0.12	{Encounter}	1	1	{Resource}	\N
0.12	{Encounter,extension}	0	*	{Extension}	\N
0.12	{Encounter,modifierExtension}	0	*	{Extension}	\N
0.12	{Encounter,text}	0	1	{Narrative}	\N
0.12	{Encounter,contained}	0	*	{Resource}	\N
0.12	{Encounter,identifier}	0	*	{Identifier}	\N
0.12	{Encounter,status}	1	1	{code}	\N
0.12	{Encounter,class}	1	1	{code}	\N
0.12	{Encounter,type}	0	*	{CodeableConcept}	\N
0.12	{Encounter,subject}	0	1	{ResourceReference}	{Patient}
0.12	{Encounter,participant}	0	*	{}	\N
0.12	{Encounter,participant,extension}	0	*	{Extension}	\N
0.12	{Encounter,participant,modifierExtension}	0	*	{Extension}	\N
0.12	{Encounter,participant,type}	0	*	{CodeableConcept}	\N
0.12	{Encounter,participant,individual}	0	1	{ResourceReference,ResourceReference}	{Practitioner,RelatedPerson}
0.12	{Encounter,period}	0	1	{Period}	\N
0.12	{Encounter,length}	0	1	{Duration}	\N
0.12	{Encounter,reason}	0	1	{CodeableConcept}	\N
0.12	{Encounter,indication}	0	1	{ResourceReference}	{Any}
0.12	{Encounter,priority}	0	1	{CodeableConcept}	\N
0.12	{Encounter,hospitalization}	0	1	{}	\N
0.12	{Encounter,hospitalization,extension}	0	*	{Extension}	\N
0.12	{Encounter,hospitalization,modifierExtension}	0	*	{Extension}	\N
0.12	{Encounter,hospitalization,preAdmissionIdentifier}	0	1	{Identifier}	\N
0.12	{Encounter,hospitalization,origin}	0	1	{ResourceReference}	{Location}
0.12	{Encounter,hospitalization,admitSource}	0	1	{CodeableConcept}	\N
0.12	{Encounter,hospitalization,period}	0	1	{Period}	\N
0.12	{Encounter,hospitalization,accomodation}	0	*	{}	\N
0.12	{Encounter,hospitalization,accomodation,extension}	0	*	{Extension}	\N
0.12	{Encounter,hospitalization,accomodation,modifierExtension}	0	*	{Extension}	\N
0.12	{Encounter,hospitalization,accomodation,bed}	0	1	{ResourceReference}	{Location}
0.12	{Encounter,hospitalization,accomodation,period}	0	1	{Period}	\N
0.12	{Encounter,hospitalization,diet}	0	1	{CodeableConcept}	\N
0.12	{Encounter,hospitalization,specialCourtesy}	0	*	{CodeableConcept}	\N
0.12	{Encounter,hospitalization,specialArrangement}	0	*	{CodeableConcept}	\N
0.12	{Encounter,hospitalization,destination}	0	1	{ResourceReference}	{Location}
0.12	{Encounter,hospitalization,dischargeDisposition}	0	1	{CodeableConcept}	\N
0.12	{Encounter,hospitalization,dischargeDiagnosis}	0	1	{ResourceReference}	{Any}
0.12	{Encounter,hospitalization,reAdmission}	0	1	{boolean}	\N
0.12	{Encounter,location}	0	*	{}	\N
0.12	{Encounter,location,extension}	0	*	{Extension}	\N
0.12	{Encounter,location,modifierExtension}	0	*	{Extension}	\N
0.12	{Encounter,location,location}	1	1	{ResourceReference}	{Location}
0.12	{Encounter,location,period}	1	1	{Period}	\N
0.12	{Encounter,serviceProvider}	0	1	{ResourceReference}	{Organization}
0.12	{Encounter,partOf}	0	1	{ResourceReference}	{Encounter}
0.12	{FamilyHistory}	1	1	{Resource}	\N
0.12	{FamilyHistory,extension}	0	*	{Extension}	\N
0.12	{FamilyHistory,modifierExtension}	0	*	{Extension}	\N
0.12	{FamilyHistory,text}	0	1	{Narrative}	\N
0.12	{FamilyHistory,contained}	0	*	{Resource}	\N
0.12	{FamilyHistory,identifier}	0	*	{Identifier}	\N
0.12	{FamilyHistory,subject}	1	1	{ResourceReference}	{Patient}
0.12	{FamilyHistory,note}	0	1	{string}	\N
0.12	{FamilyHistory,relation}	0	*	{}	\N
0.12	{FamilyHistory,relation,extension}	0	*	{Extension}	\N
0.12	{FamilyHistory,relation,modifierExtension}	0	*	{Extension}	\N
0.12	{FamilyHistory,relation,name}	0	1	{string}	\N
0.12	{FamilyHistory,relation,relationship}	1	1	{CodeableConcept}	\N
0.12	{FamilyHistory,relation,born[x]}	0	1	{Period,date,string}	\N
0.12	{FamilyHistory,relation,deceased[x]}	0	1	{boolean,Age,Range,date,string}	\N
0.12	{FamilyHistory,relation,note}	0	1	{string}	\N
0.12	{FamilyHistory,relation,condition}	0	*	{}	\N
0.12	{FamilyHistory,relation,condition,extension}	0	*	{Extension}	\N
0.12	{FamilyHistory,relation,condition,modifierExtension}	0	*	{Extension}	\N
0.12	{FamilyHistory,relation,condition,type}	1	1	{CodeableConcept}	\N
0.12	{FamilyHistory,relation,condition,outcome}	0	1	{CodeableConcept}	\N
0.12	{FamilyHistory,relation,condition,onset[x]}	0	1	{Age,Range,string}	\N
0.12	{FamilyHistory,relation,condition,note}	0	1	{string}	\N
0.12	{Group}	1	1	{Resource}	\N
0.12	{Group,extension}	0	*	{Extension}	\N
0.12	{Group,modifierExtension}	0	*	{Extension}	\N
0.12	{Group,text}	0	1	{Narrative}	\N
0.12	{Group,contained}	0	*	{Resource}	\N
0.12	{Group,identifier}	0	1	{Identifier}	\N
0.12	{Group,type}	1	1	{code}	\N
0.12	{Group,actual}	1	1	{boolean}	\N
0.12	{Group,code}	0	1	{CodeableConcept}	\N
0.12	{Group,name}	0	1	{string}	\N
0.12	{Group,quantity}	0	1	{integer}	\N
0.12	{Group,characteristic}	0	*	{}	\N
0.12	{Group,characteristic,extension}	0	*	{Extension}	\N
0.12	{Group,characteristic,modifierExtension}	0	*	{Extension}	\N
0.12	{Group,characteristic,code}	1	1	{CodeableConcept}	\N
0.12	{Group,characteristic,value[x]}	1	1	{CodeableConcept,boolean,Quantity,Range}	\N
0.12	{Group,characteristic,exclude}	1	1	{boolean}	\N
0.12	{Group,member}	0	*	{ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,Device,Medication,Substance}
0.12	{ImagingStudy}	1	1	{Resource}	\N
0.12	{ImagingStudy,extension}	0	*	{Extension}	\N
0.12	{ImagingStudy,modifierExtension}	0	*	{Extension}	\N
0.12	{ImagingStudy,text}	0	1	{Narrative}	\N
0.12	{ImagingStudy,contained}	0	*	{Resource}	\N
0.12	{ImagingStudy,dateTime}	0	1	{dateTime}	\N
0.12	{ImagingStudy,subject}	1	1	{ResourceReference}	{Patient}
0.12	{ImagingStudy,uid}	1	1	{oid}	\N
0.12	{ImagingStudy,accessionNo}	0	1	{Identifier}	\N
0.12	{ImagingStudy,identifier}	0	*	{Identifier}	\N
0.12	{ImagingStudy,order}	0	*	{ResourceReference}	{DiagnosticOrder}
0.12	{ImagingStudy,modality}	0	*	{code}	\N
0.12	{ImagingStudy,referrer}	0	1	{ResourceReference}	{Practitioner}
0.12	{ImagingStudy,availability}	0	1	{code}	\N
0.12	{ImagingStudy,url}	0	1	{uri}	\N
0.12	{ImagingStudy,numberOfSeries}	1	1	{integer}	\N
0.12	{ImagingStudy,numberOfInstances}	1	1	{integer}	\N
0.12	{ImagingStudy,clinicalInformation}	0	1	{string}	\N
0.12	{ImagingStudy,procedure}	0	*	{Coding}	\N
0.12	{ImagingStudy,interpreter}	0	1	{ResourceReference}	{Practitioner}
0.12	{ImagingStudy,description}	0	1	{string}	\N
0.12	{ImagingStudy,series}	0	*	{}	\N
0.12	{ImagingStudy,series,extension}	0	*	{Extension}	\N
0.12	{ImagingStudy,series,modifierExtension}	0	*	{Extension}	\N
0.12	{ImagingStudy,series,number}	0	1	{integer}	\N
0.12	{ImagingStudy,series,modality}	1	1	{code}	\N
0.12	{ImagingStudy,series,uid}	1	1	{oid}	\N
0.12	{ImagingStudy,series,description}	0	1	{string}	\N
0.12	{ImagingStudy,series,numberOfInstances}	1	1	{integer}	\N
0.12	{ImagingStudy,series,availability}	0	1	{code}	\N
0.12	{ImagingStudy,series,url}	0	1	{uri}	\N
0.12	{ImagingStudy,series,bodySite}	0	1	{Coding}	\N
0.12	{ImagingStudy,series,dateTime}	0	1	{dateTime}	\N
0.12	{ImagingStudy,series,instance}	1	*	{}	\N
0.12	{ImagingStudy,series,instance,extension}	0	*	{Extension}	\N
0.12	{ImagingStudy,series,instance,modifierExtension}	0	*	{Extension}	\N
0.12	{ImagingStudy,series,instance,number}	0	1	{integer}	\N
0.12	{ImagingStudy,series,instance,uid}	1	1	{oid}	\N
0.12	{ImagingStudy,series,instance,sopclass}	1	1	{oid}	\N
0.12	{ImagingStudy,series,instance,type}	0	1	{string}	\N
0.12	{ImagingStudy,series,instance,title}	0	1	{string}	\N
0.12	{ImagingStudy,series,instance,url}	0	1	{uri}	\N
0.12	{ImagingStudy,series,instance,attachment}	0	1	{ResourceReference}	{Any}
0.12	{Immunization}	1	1	{Resource}	\N
0.12	{Immunization,extension}	0	*	{Extension}	\N
0.12	{Immunization,modifierExtension}	0	*	{Extension}	\N
0.12	{Immunization,text}	0	1	{Narrative}	\N
0.12	{Immunization,contained}	0	*	{Resource}	\N
0.12	{Immunization,identifier}	0	*	{Identifier}	\N
0.12	{Immunization,date}	1	1	{dateTime}	\N
0.12	{Immunization,vaccineType}	1	1	{CodeableConcept}	\N
0.12	{Immunization,subject}	1	1	{ResourceReference}	{Patient}
0.12	{Immunization,refusedIndicator}	1	1	{boolean}	\N
0.12	{Immunization,reported}	1	1	{boolean}	\N
0.12	{Immunization,performer}	0	1	{ResourceReference}	{Practitioner}
0.12	{Immunization,requester}	0	1	{ResourceReference}	{Practitioner}
0.12	{Immunization,manufacturer}	0	1	{ResourceReference}	{Organization}
0.12	{Immunization,location}	0	1	{ResourceReference}	{Location}
0.12	{Immunization,lotNumber}	0	1	{string}	\N
0.12	{Immunization,expirationDate}	0	1	{date}	\N
0.12	{Immunization,site}	0	1	{CodeableConcept}	\N
0.12	{Immunization,route}	0	1	{CodeableConcept}	\N
0.12	{Immunization,doseQuantity}	0	1	{Quantity}	\N
0.12	{Immunization,explanation}	0	1	{}	\N
0.12	{Immunization,explanation,extension}	0	*	{Extension}	\N
0.12	{Immunization,explanation,modifierExtension}	0	*	{Extension}	\N
0.12	{Immunization,explanation,reason}	0	*	{CodeableConcept}	\N
0.12	{Immunization,explanation,refusalReason}	0	*	{CodeableConcept}	\N
0.12	{Immunization,reaction}	0	*	{}	\N
0.12	{Immunization,reaction,extension}	0	*	{Extension}	\N
0.12	{Immunization,reaction,modifierExtension}	0	*	{Extension}	\N
0.12	{Immunization,reaction,date}	0	1	{dateTime}	\N
0.12	{Immunization,reaction,detail}	0	1	{ResourceReference,ResourceReference}	{AdverseReaction,Observation}
0.12	{Immunization,reaction,reported}	0	1	{boolean}	\N
0.12	{Immunization,vaccinationProtocol}	0	*	{}	\N
0.12	{Immunization,vaccinationProtocol,extension}	0	*	{Extension}	\N
0.12	{Immunization,vaccinationProtocol,modifierExtension}	0	*	{Extension}	\N
0.12	{Immunization,vaccinationProtocol,doseSequence}	1	1	{integer}	\N
0.12	{Immunization,vaccinationProtocol,description}	0	1	{string}	\N
0.12	{Immunization,vaccinationProtocol,authority}	0	1	{ResourceReference}	{Organization}
0.12	{Immunization,vaccinationProtocol,series}	0	1	{string}	\N
0.12	{Immunization,vaccinationProtocol,seriesDoses}	0	1	{integer}	\N
0.12	{Immunization,vaccinationProtocol,doseTarget}	1	1	{CodeableConcept}	\N
0.12	{Immunization,vaccinationProtocol,doseStatus}	1	1	{CodeableConcept}	\N
0.12	{Immunization,vaccinationProtocol,doseStatusReason}	0	1	{CodeableConcept}	\N
0.12	{ImmunizationRecommendation}	1	1	{Resource}	\N
0.12	{ImmunizationRecommendation,extension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,modifierExtension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,text}	0	1	{Narrative}	\N
0.12	{ImmunizationRecommendation,contained}	0	*	{Resource}	\N
0.12	{ImmunizationRecommendation,identifier}	0	*	{Identifier}	\N
0.12	{ImmunizationRecommendation,subject}	1	1	{ResourceReference}	{Patient}
0.12	{ImmunizationRecommendation,recommendation}	1	*	{}	\N
0.12	{ImmunizationRecommendation,recommendation,extension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,recommendation,modifierExtension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,recommendation,date}	1	1	{dateTime}	\N
0.12	{ImmunizationRecommendation,recommendation,vaccineType}	1	1	{CodeableConcept}	\N
0.12	{ImmunizationRecommendation,recommendation,doseNumber}	0	1	{integer}	\N
0.12	{ImmunizationRecommendation,recommendation,forecastStatus}	1	1	{CodeableConcept}	\N
0.12	{ImmunizationRecommendation,recommendation,dateCriterion}	0	*	{}	\N
0.12	{ImmunizationRecommendation,recommendation,dateCriterion,extension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,recommendation,dateCriterion,modifierExtension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,recommendation,dateCriterion,code}	1	1	{CodeableConcept}	\N
0.12	{ImmunizationRecommendation,recommendation,dateCriterion,value}	1	1	{dateTime}	\N
0.12	{ImmunizationRecommendation,recommendation,protocol}	0	1	{}	\N
0.12	{ImmunizationRecommendation,recommendation,protocol,extension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,recommendation,protocol,modifierExtension}	0	*	{Extension}	\N
0.12	{ImmunizationRecommendation,recommendation,protocol,doseSequence}	0	1	{integer}	\N
0.12	{ImmunizationRecommendation,recommendation,protocol,description}	0	1	{string}	\N
0.12	{ImmunizationRecommendation,recommendation,protocol,authority}	0	1	{ResourceReference}	{Organization}
0.12	{ImmunizationRecommendation,recommendation,protocol,series}	0	1	{string}	\N
0.12	{ImmunizationRecommendation,recommendation,supportingImmunization}	0	*	{ResourceReference}	{Immunization}
0.12	{ImmunizationRecommendation,recommendation,supportingPatientInformation}	0	*	{ResourceReference,ResourceReference,ResourceReference}	{Observation,AdverseReaction,AllergyIntolerance}
0.12	{List}	1	1	{Resource}	\N
0.12	{List,extension}	0	*	{Extension}	\N
0.12	{List,modifierExtension}	0	*	{Extension}	\N
0.12	{List,text}	0	1	{Narrative}	\N
0.12	{List,contained}	0	*	{Resource}	\N
0.12	{List,identifier}	0	*	{Identifier}	\N
0.12	{List,code}	0	1	{CodeableConcept}	\N
0.12	{List,subject}	0	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Group,Device,Location}
0.12	{List,source}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Patient,Device}
0.12	{List,date}	0	1	{dateTime}	\N
0.12	{List,ordered}	0	1	{boolean}	\N
0.12	{List,mode}	1	1	{code}	\N
0.12	{List,entry}	0	*	{}	\N
0.12	{List,entry,extension}	0	*	{Extension}	\N
0.12	{List,entry,modifierExtension}	0	*	{Extension}	\N
0.12	{List,entry,flag}	0	*	{CodeableConcept}	\N
0.12	{List,entry,deleted}	0	1	{boolean}	\N
0.12	{List,entry,date}	0	1	{dateTime}	\N
0.12	{List,entry,item}	1	1	{ResourceReference}	{Any}
0.12	{List,emptyReason}	0	1	{CodeableConcept}	\N
0.12	{Location}	1	1	{Resource}	\N
0.12	{Location,extension}	0	*	{Extension}	\N
0.12	{Location,modifierExtension}	0	*	{Extension}	\N
0.12	{Location,text}	0	1	{Narrative}	\N
0.12	{Location,contained}	0	*	{Resource}	\N
0.12	{Location,identifier}	0	1	{Identifier}	\N
0.12	{Location,name}	0	1	{string}	\N
0.12	{Location,description}	0	1	{string}	\N
0.12	{Location,type}	0	1	{CodeableConcept}	\N
0.12	{Location,telecom}	0	*	{Contact}	\N
0.12	{Location,address}	0	1	{Address}	\N
0.12	{Location,physicalType}	0	1	{CodeableConcept}	\N
0.12	{Location,position}	0	1	{}	\N
0.12	{Location,position,extension}	0	*	{Extension}	\N
0.12	{Location,position,modifierExtension}	0	*	{Extension}	\N
0.12	{Location,position,longitude}	1	1	{decimal}	\N
0.12	{Location,position,latitude}	1	1	{decimal}	\N
0.12	{Location,position,altitude}	0	1	{decimal}	\N
0.12	{Location,managingOrganization}	0	1	{ResourceReference}	{Organization}
0.12	{Location,status}	0	1	{code}	\N
0.12	{Location,partOf}	0	1	{ResourceReference}	{Location}
0.12	{Location,mode}	0	1	{code}	\N
0.12	{Media}	1	1	{Resource}	\N
0.12	{Media,extension}	0	*	{Extension}	\N
0.12	{Media,modifierExtension}	0	*	{Extension}	\N
0.12	{Media,text}	0	1	{Narrative}	\N
0.12	{Media,contained}	0	*	{Resource}	\N
0.12	{Media,type}	1	1	{code}	\N
0.12	{Media,subtype}	0	1	{CodeableConcept}	\N
0.12	{Media,identifier}	0	*	{Identifier}	\N
0.12	{Media,dateTime}	0	1	{dateTime}	\N
0.12	{Media,subject}	0	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,Group,Device,Specimen}
0.12	{Media,operator}	0	1	{ResourceReference}	{Practitioner}
0.12	{Media,view}	0	1	{CodeableConcept}	\N
0.12	{Media,deviceName}	0	1	{string}	\N
0.12	{Media,height}	0	1	{integer}	\N
0.12	{Media,width}	0	1	{integer}	\N
0.12	{Media,frames}	0	1	{integer}	\N
0.12	{Media,length}	0	1	{integer}	\N
0.12	{Media,content}	1	1	{Attachment}	\N
0.12	{Medication}	1	1	{Resource}	\N
0.12	{Medication,extension}	0	*	{Extension}	\N
0.12	{Medication,modifierExtension}	0	*	{Extension}	\N
0.12	{Medication,text}	0	1	{Narrative}	\N
0.12	{Medication,contained}	0	*	{Resource}	\N
0.12	{Medication,name}	0	1	{string}	\N
0.12	{Medication,code}	0	1	{CodeableConcept}	\N
0.12	{Medication,isBrand}	0	1	{boolean}	\N
0.12	{Medication,manufacturer}	0	1	{ResourceReference}	{Organization}
0.12	{Medication,kind}	0	1	{code}	\N
0.12	{Medication,product}	0	1	{}	\N
0.12	{Medication,product,extension}	0	*	{Extension}	\N
0.12	{Medication,product,modifierExtension}	0	*	{Extension}	\N
0.12	{Medication,product,form}	0	1	{CodeableConcept}	\N
0.12	{Medication,product,ingredient}	0	*	{}	\N
0.12	{Medication,product,ingredient,extension}	0	*	{Extension}	\N
0.12	{Medication,product,ingredient,modifierExtension}	0	*	{Extension}	\N
0.12	{Medication,product,ingredient,item}	1	1	{ResourceReference,ResourceReference}	{Substance,Medication}
0.12	{Medication,product,ingredient,amount}	0	1	{Ratio}	\N
0.12	{Medication,package}	0	1	{}	\N
0.12	{Medication,package,extension}	0	*	{Extension}	\N
0.12	{Medication,package,modifierExtension}	0	*	{Extension}	\N
0.12	{Medication,package,container}	0	1	{CodeableConcept}	\N
0.12	{Medication,package,content}	0	*	{}	\N
0.12	{Medication,package,content,extension}	0	*	{Extension}	\N
0.12	{Medication,package,content,modifierExtension}	0	*	{Extension}	\N
0.12	{Medication,package,content,item}	1	1	{ResourceReference}	{Medication}
0.12	{Medication,package,content,amount}	0	1	{Quantity}	\N
0.12	{MedicationAdministration}	1	1	{Resource}	\N
0.12	{MedicationAdministration,extension}	0	*	{Extension}	\N
0.12	{MedicationAdministration,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationAdministration,text}	0	1	{Narrative}	\N
0.12	{MedicationAdministration,contained}	0	*	{Resource}	\N
0.12	{MedicationAdministration,identifier}	0	*	{Identifier}	\N
0.12	{MedicationAdministration,status}	1	1	{code}	\N
0.12	{MedicationAdministration,patient}	1	1	{ResourceReference}	{Patient}
0.12	{MedicationAdministration,practitioner}	1	1	{ResourceReference}	{Practitioner}
0.12	{MedicationAdministration,encounter}	0	1	{ResourceReference}	{Encounter}
0.12	{MedicationAdministration,prescription}	1	1	{ResourceReference}	{MedicationPrescription}
0.12	{MedicationAdministration,wasNotGiven}	0	1	{boolean}	\N
0.12	{MedicationAdministration,reasonNotGiven}	0	*	{CodeableConcept}	\N
0.12	{MedicationAdministration,whenGiven}	1	1	{Period}	\N
0.12	{MedicationAdministration,medication}	0	1	{ResourceReference}	{Medication}
0.12	{MedicationAdministration,device}	0	*	{ResourceReference}	{Device}
0.12	{MedicationAdministration,dosage}	0	*	{}	\N
0.12	{MedicationAdministration,dosage,extension}	0	*	{Extension}	\N
0.12	{MedicationAdministration,dosage,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationAdministration,dosage,timing[x]}	0	1	{dateTime,Period}	\N
0.12	{MedicationAdministration,dosage,asNeeded[x]}	0	1	{boolean,CodeableConcept}	\N
0.12	{MedicationAdministration,dosage,site}	0	1	{CodeableConcept}	\N
0.12	{MedicationAdministration,dosage,route}	0	1	{CodeableConcept}	\N
0.12	{MedicationAdministration,dosage,method}	0	1	{CodeableConcept}	\N
0.12	{MedicationAdministration,dosage,quantity}	0	1	{Quantity}	\N
0.12	{MedicationAdministration,dosage,rate}	0	1	{Ratio}	\N
0.12	{MedicationAdministration,dosage,maxDosePerPeriod}	0	1	{Ratio}	\N
0.12	{MedicationDispense}	1	1	{Resource}	\N
0.12	{MedicationDispense,extension}	0	*	{Extension}	\N
0.12	{MedicationDispense,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationDispense,text}	0	1	{Narrative}	\N
0.12	{MedicationDispense,contained}	0	*	{Resource}	\N
0.12	{MedicationDispense,identifier}	0	1	{Identifier}	\N
0.12	{MedicationDispense,status}	0	1	{code}	\N
0.12	{MedicationDispense,patient}	0	1	{ResourceReference}	{Patient}
0.12	{MedicationDispense,dispenser}	0	1	{ResourceReference}	{Practitioner}
0.12	{MedicationDispense,authorizingPrescription}	0	*	{ResourceReference}	{MedicationPrescription}
0.12	{MedicationDispense,dispense}	0	*	{}	\N
0.12	{MedicationDispense,dispense,extension}	0	*	{Extension}	\N
0.12	{MedicationDispense,dispense,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationDispense,dispense,identifier}	0	1	{Identifier}	\N
0.12	{MedicationDispense,dispense,status}	0	1	{code}	\N
0.12	{MedicationDispense,dispense,type}	0	1	{CodeableConcept}	\N
0.12	{MedicationDispense,dispense,quantity}	0	1	{Quantity}	\N
0.12	{MedicationDispense,dispense,medication}	0	1	{ResourceReference}	{Medication}
0.12	{MedicationDispense,dispense,whenPrepared}	0	1	{dateTime}	\N
0.12	{MedicationDispense,dispense,whenHandedOver}	0	1	{dateTime}	\N
0.12	{MedicationDispense,dispense,destination}	0	1	{ResourceReference}	{Location}
0.12	{MedicationDispense,dispense,receiver}	0	*	{ResourceReference,ResourceReference}	{Patient,Practitioner}
0.12	{MedicationDispense,dispense,dosage}	0	*	{}	\N
0.12	{MedicationDispense,dispense,dosage,extension}	0	*	{Extension}	\N
0.12	{MedicationDispense,dispense,dosage,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationDispense,dispense,dosage,additionalInstructions}	0	1	{CodeableConcept}	\N
0.12	{MedicationDispense,dispense,dosage,timing[x]}	0	1	{dateTime,Period,Schedule}	\N
0.12	{MedicationDispense,dispense,dosage,asNeeded[x]}	0	1	{boolean,CodeableConcept}	\N
0.12	{MedicationDispense,dispense,dosage,site}	0	1	{CodeableConcept}	\N
0.12	{MedicationDispense,dispense,dosage,route}	0	1	{CodeableConcept}	\N
0.12	{MedicationDispense,dispense,dosage,method}	0	1	{CodeableConcept}	\N
0.12	{MedicationDispense,dispense,dosage,quantity}	0	1	{Quantity}	\N
0.12	{MedicationDispense,dispense,dosage,rate}	0	1	{Ratio}	\N
0.12	{MedicationDispense,dispense,dosage,maxDosePerPeriod}	0	1	{Ratio}	\N
0.12	{MedicationDispense,substitution}	0	1	{}	\N
0.12	{MedicationDispense,substitution,extension}	0	*	{Extension}	\N
0.12	{MedicationDispense,substitution,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationDispense,substitution,type}	1	1	{CodeableConcept}	\N
0.12	{MedicationDispense,substitution,reason}	0	*	{CodeableConcept}	\N
0.12	{MedicationDispense,substitution,responsibleParty}	0	*	{ResourceReference}	{Practitioner}
0.12	{MedicationPrescription}	1	1	{Resource}	\N
0.12	{MedicationPrescription,extension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,text}	0	1	{Narrative}	\N
0.12	{MedicationPrescription,contained}	0	*	{Resource}	\N
0.12	{MedicationPrescription,identifier}	0	*	{Identifier}	\N
0.12	{MedicationPrescription,dateWritten}	0	1	{dateTime}	\N
0.12	{MedicationPrescription,status}	0	1	{code}	\N
0.12	{MedicationPrescription,patient}	0	1	{ResourceReference}	{Patient}
0.12	{MedicationPrescription,prescriber}	0	1	{ResourceReference}	{Practitioner}
0.12	{MedicationPrescription,encounter}	0	1	{ResourceReference}	{Encounter}
0.12	{MedicationPrescription,reason[x]}	0	1	{CodeableConcept,ResourceReference}	{Condition}
0.12	{MedicationPrescription,medication}	0	1	{ResourceReference}	{Medication}
0.12	{MedicationPrescription,dosageInstruction}	0	*	{}	\N
0.12	{MedicationPrescription,dosageInstruction,extension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,dosageInstruction,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,dosageInstruction,text}	0	1	{string}	\N
0.12	{MedicationPrescription,dosageInstruction,additionalInstructions}	0	1	{CodeableConcept}	\N
0.12	{MedicationPrescription,dosageInstruction,timing[x]}	0	1	{dateTime,Period,Schedule}	\N
0.12	{MedicationPrescription,dosageInstruction,asNeeded[x]}	0	1	{boolean,CodeableConcept}	\N
0.12	{MedicationPrescription,dosageInstruction,site}	0	1	{CodeableConcept}	\N
0.12	{MedicationPrescription,dosageInstruction,route}	0	1	{CodeableConcept}	\N
0.12	{MedicationPrescription,dosageInstruction,method}	0	1	{CodeableConcept}	\N
0.12	{MedicationPrescription,dosageInstruction,doseQuantity}	0	1	{Quantity}	\N
0.12	{MedicationPrescription,dosageInstruction,rate}	0	1	{Ratio}	\N
0.12	{MedicationPrescription,dosageInstruction,maxDosePerPeriod}	0	1	{Ratio}	\N
0.12	{MedicationPrescription,dispense}	0	1	{}	\N
0.12	{MedicationPrescription,dispense,extension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,dispense,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,dispense,medication}	0	1	{ResourceReference}	{Medication}
0.12	{MedicationPrescription,dispense,validityPeriod}	0	1	{Period}	\N
0.12	{MedicationPrescription,dispense,numberOfRepeatsAllowed}	0	1	{integer}	\N
0.12	{MedicationPrescription,dispense,quantity}	0	1	{Quantity}	\N
0.12	{MedicationPrescription,dispense,expectedSupplyDuration}	0	1	{Duration}	\N
0.12	{MedicationPrescription,substitution}	0	1	{}	\N
0.12	{MedicationPrescription,substitution,extension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,substitution,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationPrescription,substitution,type}	1	1	{CodeableConcept}	\N
0.12	{MedicationPrescription,substitution,reason}	0	1	{CodeableConcept}	\N
0.12	{MedicationStatement}	1	1	{Resource}	\N
0.12	{MedicationStatement,extension}	0	*	{Extension}	\N
0.12	{MedicationStatement,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationStatement,text}	0	1	{Narrative}	\N
0.12	{MedicationStatement,contained}	0	*	{Resource}	\N
0.12	{MedicationStatement,identifier}	0	*	{Identifier}	\N
0.12	{MedicationStatement,patient}	0	1	{ResourceReference}	{Patient}
0.12	{MedicationStatement,wasNotGiven}	0	1	{boolean}	\N
0.12	{MedicationStatement,reasonNotGiven}	0	*	{CodeableConcept}	\N
0.12	{MedicationStatement,whenGiven}	0	1	{Period}	\N
0.12	{MedicationStatement,medication}	0	1	{ResourceReference}	{Medication}
0.12	{MedicationStatement,device}	0	*	{ResourceReference}	{Device}
0.12	{MedicationStatement,dosage}	0	*	{}	\N
0.12	{MedicationStatement,dosage,extension}	0	*	{Extension}	\N
0.12	{MedicationStatement,dosage,modifierExtension}	0	*	{Extension}	\N
0.12	{MedicationStatement,dosage,timing}	0	1	{Schedule}	\N
0.12	{MedicationStatement,dosage,asNeeded[x]}	0	1	{boolean,CodeableConcept}	\N
0.12	{MedicationStatement,dosage,site}	0	1	{CodeableConcept}	\N
0.12	{MedicationStatement,dosage,route}	0	1	{CodeableConcept}	\N
0.12	{MedicationStatement,dosage,method}	0	1	{CodeableConcept}	\N
0.12	{MedicationStatement,dosage,quantity}	0	1	{Quantity}	\N
0.12	{MedicationStatement,dosage,rate}	0	1	{Ratio}	\N
0.12	{MedicationStatement,dosage,maxDosePerPeriod}	0	1	{Ratio}	\N
0.12	{MessageHeader}	1	1	{Resource}	\N
0.12	{MessageHeader,extension}	0	*	{Extension}	\N
0.12	{MessageHeader,modifierExtension}	0	*	{Extension}	\N
0.12	{MessageHeader,text}	0	1	{Narrative}	\N
0.12	{MessageHeader,contained}	0	*	{Resource}	\N
0.12	{MessageHeader,identifier}	1	1	{id}	\N
0.12	{MessageHeader,timestamp}	1	1	{instant}	\N
0.12	{MessageHeader,event}	1	1	{Coding}	\N
0.12	{MessageHeader,response}	0	1	{}	\N
0.12	{MessageHeader,response,extension}	0	*	{Extension}	\N
0.12	{MessageHeader,response,modifierExtension}	0	*	{Extension}	\N
0.12	{MessageHeader,response,identifier}	1	1	{id}	\N
0.12	{MessageHeader,response,code}	1	1	{code}	\N
0.12	{MessageHeader,response,details}	0	1	{ResourceReference}	{OperationOutcome}
0.12	{MessageHeader,source}	1	1	{}	\N
0.12	{MessageHeader,source,extension}	0	*	{Extension}	\N
0.12	{MessageHeader,source,modifierExtension}	0	*	{Extension}	\N
0.12	{MessageHeader,source,name}	0	1	{string}	\N
0.12	{MessageHeader,source,software}	1	1	{string}	\N
0.12	{MessageHeader,source,version}	0	1	{string}	\N
0.12	{MessageHeader,source,contact}	0	1	{Contact}	\N
0.12	{MessageHeader,source,endpoint}	1	1	{uri}	\N
0.12	{MessageHeader,destination}	0	*	{}	\N
0.12	{MessageHeader,destination,extension}	0	*	{Extension}	\N
0.12	{MessageHeader,destination,modifierExtension}	0	*	{Extension}	\N
0.12	{MessageHeader,destination,name}	0	1	{string}	\N
0.12	{MessageHeader,destination,target}	0	1	{ResourceReference}	{Device}
0.12	{MessageHeader,destination,endpoint}	1	1	{uri}	\N
0.12	{MessageHeader,enterer}	0	1	{ResourceReference}	{Practitioner}
0.12	{MessageHeader,author}	0	1	{ResourceReference}	{Practitioner}
0.12	{MessageHeader,receiver}	0	1	{ResourceReference,ResourceReference}	{Practitioner,Organization}
0.12	{MessageHeader,responsible}	0	1	{ResourceReference,ResourceReference}	{Practitioner,Organization}
0.12	{MessageHeader,reason}	0	1	{CodeableConcept}	\N
0.12	{MessageHeader,data}	0	*	{ResourceReference}	{Any}
0.12	{Observation}	1	1	{Resource}	\N
0.12	{Observation,extension}	0	*	{Extension}	\N
0.12	{Observation,modifierExtension}	0	*	{Extension}	\N
0.12	{Observation,text}	0	1	{Narrative}	\N
0.12	{Observation,contained}	0	*	{Resource}	\N
0.12	{Observation,name}	1	1	{CodeableConcept}	\N
0.12	{Observation,value[x]}	0	1	{Quantity,CodeableConcept,Attachment,Ratio,Period,SampledData,string}	\N
0.12	{Observation,interpretation}	0	1	{CodeableConcept}	\N
0.12	{Observation,comments}	0	1	{string}	\N
0.12	{Observation,applies[x]}	0	1	{dateTime,Period}	\N
0.12	{Observation,issued}	0	1	{instant}	\N
0.12	{Observation,status}	1	1	{code}	\N
0.12	{Observation,reliability}	1	1	{code}	\N
0.12	{Observation,bodySite}	0	1	{CodeableConcept}	\N
0.12	{Observation,method}	0	1	{CodeableConcept}	\N
0.12	{Observation,identifier}	0	1	{Identifier}	\N
0.12	{Observation,subject}	0	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Group,Device,Location}
0.12	{Observation,specimen}	0	1	{ResourceReference}	{Specimen}
0.12	{Observation,performer}	0	*	{ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Device,Organization}
0.12	{Observation,referenceRange}	0	*	{}	\N
0.12	{Observation,referenceRange,extension}	0	*	{Extension}	\N
0.12	{Observation,referenceRange,modifierExtension}	0	*	{Extension}	\N
0.12	{Observation,referenceRange,low}	0	1	{Quantity}	\N
0.12	{Observation,referenceRange,high}	0	1	{Quantity}	\N
0.12	{Observation,referenceRange,meaning}	0	1	{CodeableConcept}	\N
0.12	{Observation,referenceRange,age}	0	1	{Range}	\N
0.12	{Observation,related}	0	*	{}	\N
0.12	{Observation,related,extension}	0	*	{Extension}	\N
0.12	{Observation,related,modifierExtension}	0	*	{Extension}	\N
0.12	{Observation,related,type}	0	1	{code}	\N
0.12	{Observation,related,target}	1	1	{ResourceReference}	{Observation}
0.12	{OperationOutcome}	1	1	{Resource}	\N
0.12	{OperationOutcome,extension}	0	*	{Extension}	\N
0.12	{OperationOutcome,modifierExtension}	0	*	{Extension}	\N
0.12	{OperationOutcome,text}	0	1	{Narrative}	\N
0.12	{OperationOutcome,contained}	0	*	{Resource}	\N
0.12	{OperationOutcome,issue}	1	*	{}	\N
0.12	{OperationOutcome,issue,extension}	0	*	{Extension}	\N
0.12	{OperationOutcome,issue,modifierExtension}	0	*	{Extension}	\N
0.12	{OperationOutcome,issue,severity}	1	1	{code}	\N
0.12	{OperationOutcome,issue,type}	0	1	{Coding}	\N
0.12	{OperationOutcome,issue,details}	0	1	{string}	\N
0.12	{OperationOutcome,issue,location}	0	*	{string}	\N
0.12	{Order}	1	1	{Resource}	\N
0.12	{Order,extension}	0	*	{Extension}	\N
0.12	{Order,modifierExtension}	0	*	{Extension}	\N
0.12	{Order,text}	0	1	{Narrative}	\N
0.12	{Order,contained}	0	*	{Resource}	\N
0.12	{Order,identifier}	0	*	{Identifier}	\N
0.12	{Order,date}	0	1	{dateTime}	\N
0.12	{Order,subject}	0	1	{ResourceReference}	{Patient}
0.12	{Order,source}	0	1	{ResourceReference}	{Practitioner}
0.12	{Order,target}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Organization,Device,Practitioner}
0.12	{Order,reason[x]}	0	1	{CodeableConcept,ResourceReference}	{Any}
0.12	{Order,authority}	0	1	{ResourceReference}	{Any}
0.12	{Order,when}	0	1	{}	\N
0.12	{Order,when,extension}	0	*	{Extension}	\N
0.12	{Order,when,modifierExtension}	0	*	{Extension}	\N
0.12	{Order,when,code}	0	1	{CodeableConcept}	\N
0.12	{Order,when,schedule}	0	1	{Schedule}	\N
0.12	{Order,detail}	1	*	{ResourceReference}	{Any}
0.12	{OrderResponse}	1	1	{Resource}	\N
0.12	{OrderResponse,extension}	0	*	{Extension}	\N
0.12	{OrderResponse,modifierExtension}	0	*	{Extension}	\N
0.12	{OrderResponse,text}	0	1	{Narrative}	\N
0.12	{OrderResponse,contained}	0	*	{Resource}	\N
0.12	{OrderResponse,identifier}	0	*	{Identifier}	\N
0.12	{OrderResponse,request}	1	1	{ResourceReference}	{Order}
0.12	{OrderResponse,date}	0	1	{dateTime}	\N
0.12	{OrderResponse,who}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Organization,Device}
0.12	{OrderResponse,authority[x]}	0	1	{CodeableConcept,ResourceReference}	{Any}
0.12	{OrderResponse,code}	1	1	{code}	\N
0.12	{OrderResponse,description}	0	1	{string}	\N
0.12	{OrderResponse,fulfillment}	0	*	{ResourceReference}	{Any}
0.12	{Organization}	1	1	{Resource}	\N
0.12	{Organization,extension}	0	*	{Extension}	\N
0.12	{Organization,modifierExtension}	0	*	{Extension}	\N
0.12	{Organization,text}	0	1	{Narrative}	\N
0.12	{Organization,contained}	0	*	{Resource}	\N
0.12	{Organization,identifier}	0	*	{Identifier}	\N
0.12	{Organization,name}	0	1	{string}	\N
0.12	{Organization,type}	0	1	{CodeableConcept}	\N
0.12	{Organization,telecom}	0	*	{Contact}	\N
0.12	{Organization,address}	0	*	{Address}	\N
0.12	{Organization,partOf}	0	1	{ResourceReference}	{Organization}
0.12	{Organization,contact}	0	*	{}	\N
0.12	{Organization,contact,extension}	0	*	{Extension}	\N
0.12	{Organization,contact,modifierExtension}	0	*	{Extension}	\N
0.12	{Organization,contact,purpose}	0	1	{CodeableConcept}	\N
0.12	{Organization,contact,name}	0	1	{HumanName}	\N
0.12	{Organization,contact,telecom}	0	*	{Contact}	\N
0.12	{Organization,contact,address}	0	1	{Address}	\N
0.12	{Organization,contact,gender}	0	1	{CodeableConcept}	\N
0.12	{Organization,location}	0	*	{ResourceReference}	{Location}
0.12	{Organization,active}	0	1	{boolean}	\N
0.12	{Other}	1	1	{Resource}	\N
0.12	{Other,extension}	0	*	{Extension}	\N
0.12	{Other,modifierExtension}	0	*	{Extension}	\N
0.12	{Other,text}	0	1	{Narrative}	\N
0.12	{Other,contained}	0	*	{Resource}	\N
0.12	{Other,identifier}	0	*	{Identifier}	\N
0.12	{Other,code}	1	1	{CodeableConcept}	\N
0.12	{Other,subject}	0	1	{ResourceReference}	{Any}
0.12	{Other,author}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Patient,RelatedPerson}
0.12	{Other,created}	0	1	{date}	\N
0.12	{Patient}	1	1	{Resource}	\N
0.12	{Patient,extension}	0	*	{Extension}	\N
0.12	{Patient,modifierExtension}	0	*	{Extension}	\N
0.12	{Patient,text}	0	1	{Narrative}	\N
0.12	{Patient,contained}	0	*	{Resource}	\N
0.12	{Patient,identifier}	0	*	{Identifier}	\N
0.12	{Patient,name}	0	*	{HumanName}	\N
0.12	{Patient,telecom}	0	*	{Contact}	\N
0.12	{Patient,gender}	0	1	{CodeableConcept}	\N
0.12	{Patient,birthDate}	0	1	{dateTime}	\N
0.12	{Patient,deceased[x]}	0	1	{boolean,dateTime}	\N
0.12	{Patient,address}	0	*	{Address}	\N
0.12	{Patient,maritalStatus}	0	1	{CodeableConcept}	\N
0.12	{Patient,multipleBirth[x]}	0	1	{boolean,integer}	\N
0.12	{Patient,photo}	0	*	{Attachment}	\N
0.12	{Patient,contact}	0	*	{}	\N
0.12	{Patient,contact,extension}	0	*	{Extension}	\N
0.12	{Patient,contact,modifierExtension}	0	*	{Extension}	\N
0.12	{Patient,contact,relationship}	0	*	{CodeableConcept}	\N
0.12	{Patient,contact,name}	0	1	{HumanName}	\N
0.12	{Patient,contact,telecom}	0	*	{Contact}	\N
0.12	{Patient,contact,address}	0	1	{Address}	\N
0.12	{Patient,contact,gender}	0	1	{CodeableConcept}	\N
0.12	{Patient,contact,organization}	0	1	{ResourceReference}	{Organization}
0.12	{Patient,animal}	0	1	{}	\N
0.12	{Patient,animal,extension}	0	*	{Extension}	\N
0.12	{Patient,animal,modifierExtension}	0	*	{Extension}	\N
0.12	{Patient,animal,species}	1	1	{CodeableConcept}	\N
0.12	{Patient,animal,breed}	0	1	{CodeableConcept}	\N
0.12	{Patient,animal,genderStatus}	0	1	{CodeableConcept}	\N
0.12	{Patient,communication}	0	*	{CodeableConcept}	\N
0.12	{Patient,careProvider}	0	*	{ResourceReference,ResourceReference}	{Organization,Practitioner}
0.12	{Patient,managingOrganization}	0	1	{ResourceReference}	{Organization}
0.12	{Patient,link}	0	*	{}	\N
0.12	{Patient,link,extension}	0	*	{Extension}	\N
0.12	{Patient,link,modifierExtension}	0	*	{Extension}	\N
0.12	{Patient,link,other}	1	1	{ResourceReference}	{Patient}
0.12	{Patient,link,type}	1	1	{code}	\N
0.12	{Patient,active}	0	1	{boolean}	\N
0.12	{Practitioner}	1	1	{Resource}	\N
0.12	{Practitioner,extension}	0	*	{Extension}	\N
0.12	{Practitioner,modifierExtension}	0	*	{Extension}	\N
0.12	{Practitioner,text}	0	1	{Narrative}	\N
0.12	{Practitioner,contained}	0	*	{Resource}	\N
0.12	{Practitioner,identifier}	0	*	{Identifier}	\N
0.12	{Practitioner,name}	0	1	{HumanName}	\N
0.12	{Practitioner,telecom}	0	*	{Contact}	\N
0.12	{Practitioner,address}	0	1	{Address}	\N
0.12	{Practitioner,gender}	0	1	{CodeableConcept}	\N
0.12	{Practitioner,birthDate}	0	1	{dateTime}	\N
0.12	{Practitioner,photo}	0	*	{Attachment}	\N
0.12	{Practitioner,organization}	0	1	{ResourceReference}	{Organization}
0.12	{Practitioner,role}	0	*	{CodeableConcept}	\N
0.12	{Practitioner,specialty}	0	*	{CodeableConcept}	\N
0.12	{Practitioner,period}	0	1	{Period}	\N
0.12	{Practitioner,location}	0	*	{ResourceReference}	{Location}
0.12	{Practitioner,qualification}	0	*	{}	\N
0.12	{Practitioner,qualification,extension}	0	*	{Extension}	\N
0.12	{Practitioner,qualification,modifierExtension}	0	*	{Extension}	\N
0.12	{Practitioner,qualification,code}	1	1	{CodeableConcept}	\N
0.12	{Practitioner,qualification,period}	0	1	{Period}	\N
0.12	{Practitioner,qualification,issuer}	0	1	{ResourceReference}	{Organization}
0.12	{Practitioner,communication}	0	*	{CodeableConcept}	\N
0.12	{Procedure}	1	1	{Resource}	\N
0.12	{Procedure,extension}	0	*	{Extension}	\N
0.12	{Procedure,modifierExtension}	0	*	{Extension}	\N
0.12	{Procedure,text}	0	1	{Narrative}	\N
0.12	{Procedure,contained}	0	*	{Resource}	\N
0.12	{Procedure,identifier}	0	*	{Identifier}	\N
0.12	{Procedure,subject}	1	1	{ResourceReference}	{Patient}
0.12	{Procedure,type}	1	1	{CodeableConcept}	\N
0.12	{Procedure,bodySite}	0	*	{CodeableConcept}	\N
0.12	{Procedure,indication}	0	*	{CodeableConcept}	\N
0.12	{Procedure,performer}	0	*	{}	\N
0.12	{Procedure,performer,extension}	0	*	{Extension}	\N
0.12	{Procedure,performer,modifierExtension}	0	*	{Extension}	\N
0.12	{Procedure,performer,person}	0	1	{ResourceReference}	{Practitioner}
0.12	{Procedure,performer,role}	0	1	{CodeableConcept}	\N
0.12	{Procedure,date}	0	1	{Period}	\N
0.12	{Procedure,encounter}	0	1	{ResourceReference}	{Encounter}
0.12	{Procedure,outcome}	0	1	{string}	\N
0.12	{Procedure,report}	0	*	{ResourceReference}	{DiagnosticReport}
0.12	{Procedure,complication}	0	*	{CodeableConcept}	\N
0.12	{Procedure,followUp}	0	1	{string}	\N
0.12	{Procedure,relatedItem}	0	*	{}	\N
0.12	{Procedure,relatedItem,extension}	0	*	{Extension}	\N
0.12	{Procedure,relatedItem,modifierExtension}	0	*	{Extension}	\N
0.12	{Procedure,relatedItem,type}	0	1	{code}	\N
0.12	{Procedure,relatedItem,target}	0	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{AdverseReaction,AllergyIntolerance,CarePlan,Condition,DeviceObservationReport,DiagnosticReport,FamilyHistory,ImagingStudy,Immunization,ImmunizationRecommendation,MedicationAdministration,MedicationDispense,MedicationPrescription,MedicationStatement,Observation,Procedure}
0.12	{Procedure,notes}	0	1	{string}	\N
0.12	{Profile}	1	1	{Resource}	\N
0.12	{Profile,extension}	0	*	{Extension}	\N
0.12	{Profile,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,text}	0	1	{Narrative}	\N
0.12	{Profile,contained}	0	*	{Resource}	\N
0.12	{Profile,identifier}	0	1	{string}	\N
0.12	{Profile,version}	0	1	{string}	\N
0.12	{Profile,name}	1	1	{string}	\N
0.12	{Profile,publisher}	0	1	{string}	\N
0.12	{Profile,telecom}	0	*	{Contact}	\N
0.12	{Profile,description}	0	1	{string}	\N
0.12	{Profile,code}	0	*	{Coding}	\N
0.12	{Profile,status}	1	1	{code}	\N
0.12	{Profile,experimental}	0	1	{boolean}	\N
0.12	{Profile,date}	0	1	{dateTime}	\N
0.12	{Profile,requirements}	0	1	{string}	\N
0.12	{Profile,fhirVersion}	0	1	{id}	\N
0.12	{Profile,mapping}	0	*	{}	\N
0.12	{Profile,mapping,extension}	0	*	{Extension}	\N
0.12	{Profile,mapping,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,mapping,identity}	1	1	{id}	\N
0.12	{Profile,mapping,uri}	0	1	{uri}	\N
0.12	{Profile,mapping,name}	0	1	{string}	\N
0.12	{Profile,mapping,comments}	0	1	{string}	\N
0.12	{Profile,structure}	0	*	{}	\N
0.12	{Profile,structure,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,type}	1	1	{code}	\N
0.12	{Profile,structure,name}	0	1	{string}	\N
0.12	{Profile,structure,publish}	0	1	{boolean}	\N
0.12	{Profile,structure,purpose}	0	1	{string}	\N
0.12	{Profile,structure,element}	0	*	{}	\N
0.12	{Profile,structure,element,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,path}	1	1	{string}	\N
0.12	{Profile,structure,element,representation}	0	*	{code}	\N
0.12	{Profile,structure,element,name}	0	1	{string}	\N
0.12	{Profile,structure,element,slicing}	0	1	{}	\N
0.12	{Profile,structure,element,slicing,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,slicing,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,slicing,discriminator}	1	1	{id}	\N
0.12	{Profile,structure,element,slicing,ordered}	1	1	{boolean}	\N
0.12	{Profile,structure,element,slicing,rules}	1	1	{code}	\N
0.12	{Profile,structure,element,definition}	0	1	{}	\N
0.12	{Profile,structure,element,definition,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,short}	1	1	{string}	\N
0.12	{Profile,structure,element,definition,formal}	1	1	{string}	\N
0.12	{Profile,structure,element,definition,comments}	0	1	{string}	\N
0.12	{Profile,structure,element,definition,requirements}	0	1	{string}	\N
0.12	{Profile,structure,element,definition,synonym}	0	*	{string}	\N
0.12	{Profile,structure,element,definition,min}	1	1	{integer}	\N
0.12	{Profile,structure,element,definition,max}	1	1	{string}	\N
0.12	{Profile,structure,element,definition,type}	0	*	{}	\N
0.12	{Profile,structure,element,definition,type,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,type,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,type,code}	1	1	{code}	\N
0.12	{Profile,structure,element,definition,type,profile}	0	1	{uri}	\N
0.12	{Profile,structure,element,definition,type,aggregation}	0	*	{code}	\N
0.12	{Profile,structure,element,definition,nameReference}	0	1	{string}	\N
0.12	{Profile,structure,element,definition,value[x]}	0	1	{*}	\N
0.12	{Profile,structure,element,definition,example[x]}	0	1	{*}	\N
0.12	{Profile,structure,element,definition,maxLength}	0	1	{integer}	\N
0.12	{Profile,structure,element,definition,condition}	0	*	{id}	\N
0.12	{Profile,structure,element,definition,constraint}	0	*	{}	\N
0.12	{Profile,structure,element,definition,constraint,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,constraint,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,constraint,key}	1	1	{id}	\N
0.12	{Profile,structure,element,definition,constraint,name}	0	1	{string}	\N
0.12	{Profile,structure,element,definition,constraint,severity}	1	1	{code}	\N
0.12	{Profile,structure,element,definition,constraint,human}	1	1	{string}	\N
0.12	{Profile,structure,element,definition,constraint,xpath}	1	1	{string}	\N
0.12	{Profile,structure,element,definition,mustSupport}	0	1	{boolean}	\N
0.12	{Profile,structure,element,definition,isModifier}	1	1	{boolean}	\N
0.12	{Profile,structure,element,definition,binding}	0	1	{}	\N
0.12	{Profile,structure,element,definition,binding,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,binding,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,binding,name}	1	1	{string}	\N
0.12	{Profile,structure,element,definition,binding,isExtensible}	1	1	{boolean}	\N
0.12	{Profile,structure,element,definition,binding,conformance}	0	1	{code}	\N
0.12	{Profile,structure,element,definition,binding,description}	0	1	{string}	\N
0.12	{Profile,structure,element,definition,binding,reference[x]}	0	1	{uri,ResourceReference}	{ValueSet}
0.12	{Profile,structure,element,definition,mapping}	0	*	{}	\N
0.12	{Profile,structure,element,definition,mapping,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,mapping,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,element,definition,mapping,identity}	1	1	{id}	\N
0.12	{Profile,structure,element,definition,mapping,map}	1	1	{string}	\N
0.12	{Profile,structure,searchParam}	0	*	{}	\N
0.12	{Profile,structure,searchParam,extension}	0	*	{Extension}	\N
0.12	{Profile,structure,searchParam,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,structure,searchParam,name}	1	1	{string}	\N
0.12	{Profile,structure,searchParam,type}	1	1	{code}	\N
0.12	{Profile,structure,searchParam,documentation}	1	1	{string}	\N
0.12	{Profile,structure,searchParam,xpath}	0	1	{string}	\N
0.12	{Profile,structure,searchParam,target}	0	*	{code}	\N
0.12	{Profile,extensionDefn}	0	*	{}	\N
0.12	{Profile,extensionDefn,extension}	0	*	{Extension}	\N
0.12	{Profile,extensionDefn,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,extensionDefn,code}	1	1	{code}	\N
0.12	{Profile,extensionDefn,display}	0	1	{string}	\N
0.12	{Profile,extensionDefn,contextType}	1	1	{code}	\N
0.12	{Profile,extensionDefn,context}	1	*	{string}	\N
0.12	{Profile,extensionDefn,definition}	1	1	{}	\N
0.12	{Profile,query}	0	*	{}	\N
0.12	{Profile,query,extension}	0	*	{Extension}	\N
0.12	{Profile,query,modifierExtension}	0	*	{Extension}	\N
0.12	{Profile,query,name}	1	1	{string}	\N
0.12	{Profile,query,documentation}	1	1	{string}	\N
0.12	{Profile,query,parameter}	0	*	{}	\N
0.12	{Provenance}	1	1	{Resource}	\N
0.12	{Provenance,extension}	0	*	{Extension}	\N
0.12	{Provenance,modifierExtension}	0	*	{Extension}	\N
0.12	{Provenance,text}	0	1	{Narrative}	\N
0.12	{Provenance,contained}	0	*	{Resource}	\N
0.12	{Provenance,target}	1	*	{ResourceReference}	{Any}
0.12	{Provenance,period}	0	1	{Period}	\N
0.12	{Provenance,recorded}	1	1	{instant}	\N
0.12	{Provenance,reason}	0	1	{CodeableConcept}	\N
0.12	{Provenance,location}	0	1	{ResourceReference}	{Location}
0.12	{Provenance,policy}	0	*	{uri}	\N
0.12	{Provenance,agent}	0	*	{}	\N
0.12	{Provenance,agent,extension}	0	*	{Extension}	\N
0.12	{Provenance,agent,modifierExtension}	0	*	{Extension}	\N
0.12	{Provenance,agent,role}	1	1	{Coding}	\N
0.12	{Provenance,agent,type}	1	1	{Coding}	\N
0.12	{Provenance,agent,reference}	1	1	{uri}	\N
0.12	{Provenance,agent,display}	0	1	{string}	\N
0.12	{Provenance,entity}	0	*	{}	\N
0.12	{Provenance,entity,extension}	0	*	{Extension}	\N
0.12	{Provenance,entity,modifierExtension}	0	*	{Extension}	\N
0.12	{Provenance,entity,role}	1	1	{code}	\N
0.12	{Provenance,entity,type}	1	1	{Coding}	\N
0.12	{Provenance,entity,reference}	1	1	{uri}	\N
0.12	{Provenance,entity,display}	0	1	{string}	\N
0.12	{Provenance,entity,agent}	0	1	{}	\N
0.12	{Provenance,integritySignature}	0	1	{string}	\N
0.12	{Query}	1	1	{Resource}	\N
0.12	{Query,extension}	0	*	{Extension}	\N
0.12	{Query,modifierExtension}	0	*	{Extension}	\N
0.12	{Query,text}	0	1	{Narrative}	\N
0.12	{Query,contained}	0	*	{Resource}	\N
0.12	{Query,identifier}	1	1	{uri}	\N
0.12	{Query,parameter}	1	*	{Extension}	\N
0.12	{Query,response}	0	1	{}	\N
0.12	{Query,response,extension}	0	*	{Extension}	\N
0.12	{Query,response,modifierExtension}	0	*	{Extension}	\N
0.12	{Query,response,identifier}	1	1	{uri}	\N
0.12	{Query,response,outcome}	1	1	{code}	\N
0.12	{Query,response,total}	0	1	{integer}	\N
0.12	{Query,response,parameter}	0	*	{Extension}	\N
0.12	{Query,response,first}	0	*	{Extension}	\N
0.12	{Query,response,previous}	0	*	{Extension}	\N
0.12	{Query,response,next}	0	*	{Extension}	\N
0.12	{Query,response,last}	0	*	{Extension}	\N
0.12	{Query,response,reference}	0	*	{ResourceReference}	{Any}
0.12	{Questionnaire}	1	1	{Resource}	\N
0.12	{Questionnaire,extension}	0	*	{Extension}	\N
0.12	{Questionnaire,modifierExtension}	0	*	{Extension}	\N
0.12	{Questionnaire,text}	0	1	{Narrative}	\N
0.12	{Questionnaire,contained}	0	*	{Resource}	\N
0.12	{Questionnaire,status}	1	1	{code}	\N
0.12	{Questionnaire,authored}	1	1	{dateTime}	\N
0.12	{Questionnaire,subject}	0	1	{ResourceReference,ResourceReference}	{Patient,RelatedPerson}
0.12	{Questionnaire,author}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Patient,RelatedPerson}
0.12	{Questionnaire,source}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Patient,Practitioner,RelatedPerson}
0.12	{Questionnaire,name}	0	1	{CodeableConcept}	\N
0.12	{Questionnaire,identifier}	0	*	{Identifier}	\N
0.12	{Questionnaire,encounter}	0	1	{ResourceReference}	{Encounter}
0.12	{Questionnaire,group}	0	1	{}	\N
0.12	{Questionnaire,group,extension}	0	*	{Extension}	\N
0.12	{Questionnaire,group,modifierExtension}	0	*	{Extension}	\N
0.12	{Questionnaire,group,name}	0	1	{CodeableConcept}	\N
0.12	{Questionnaire,group,header}	0	1	{string}	\N
0.12	{Questionnaire,group,text}	0	1	{string}	\N
0.12	{Questionnaire,group,subject}	0	1	{ResourceReference}	{Any}
0.12	{Questionnaire,group,group}	0	*	{}	\N
0.12	{Questionnaire,group,question}	0	*	{}	\N
0.12	{Questionnaire,group,question,extension}	0	*	{Extension}	\N
0.12	{Questionnaire,group,question,modifierExtension}	0	*	{Extension}	\N
0.12	{Questionnaire,group,question,name}	0	1	{CodeableConcept}	\N
0.12	{Questionnaire,group,question,text}	0	1	{string}	\N
0.12	{Questionnaire,group,question,answer[x]}	0	1	{decimal,integer,boolean,date,string,dateTime,instant}	\N
0.12	{Questionnaire,group,question,choice}	0	*	{Coding}	\N
0.12	{Questionnaire,group,question,options}	0	1	{ResourceReference}	{ValueSet}
0.12	{Questionnaire,group,question,data[x]}	0	1	{*}	\N
0.12	{Questionnaire,group,question,remarks}	0	1	{string}	\N
0.12	{Questionnaire,group,question,group}	0	*	{}	\N
0.12	{RelatedPerson}	1	1	{Resource}	\N
0.12	{RelatedPerson,extension}	0	*	{Extension}	\N
0.12	{RelatedPerson,modifierExtension}	0	*	{Extension}	\N
0.12	{RelatedPerson,text}	0	1	{Narrative}	\N
0.12	{RelatedPerson,contained}	0	*	{Resource}	\N
0.12	{RelatedPerson,identifier}	0	*	{Identifier}	\N
0.12	{RelatedPerson,patient}	1	1	{ResourceReference}	{Patient}
0.12	{RelatedPerson,relationship}	0	1	{CodeableConcept}	\N
0.12	{RelatedPerson,name}	0	1	{HumanName}	\N
0.12	{RelatedPerson,telecom}	0	*	{Contact}	\N
0.12	{RelatedPerson,gender}	0	1	{CodeableConcept}	\N
0.12	{RelatedPerson,address}	0	1	{Address}	\N
0.12	{RelatedPerson,photo}	0	*	{Attachment}	\N
0.12	{SecurityEvent}	1	1	{Resource}	\N
0.12	{SecurityEvent,extension}	0	*	{Extension}	\N
0.12	{SecurityEvent,modifierExtension}	0	*	{Extension}	\N
0.12	{SecurityEvent,text}	0	1	{Narrative}	\N
0.12	{SecurityEvent,contained}	0	*	{Resource}	\N
0.12	{SecurityEvent,event}	1	1	{}	\N
0.12	{SecurityEvent,event,extension}	0	*	{Extension}	\N
0.12	{SecurityEvent,event,modifierExtension}	0	*	{Extension}	\N
0.12	{SecurityEvent,event,type}	1	1	{CodeableConcept}	\N
0.12	{SecurityEvent,event,subtype}	0	*	{CodeableConcept}	\N
0.12	{SecurityEvent,event,action}	0	1	{code}	\N
0.12	{SecurityEvent,event,dateTime}	1	1	{instant}	\N
0.12	{SecurityEvent,event,outcome}	0	1	{code}	\N
0.12	{SecurityEvent,event,outcomeDesc}	0	1	{string}	\N
0.12	{SecurityEvent,participant}	1	*	{}	\N
0.12	{SecurityEvent,participant,extension}	0	*	{Extension}	\N
0.12	{SecurityEvent,participant,modifierExtension}	0	*	{Extension}	\N
0.12	{SecurityEvent,participant,role}	0	*	{CodeableConcept}	\N
0.12	{SecurityEvent,participant,reference}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Practitioner,Patient,Device}
0.12	{SecurityEvent,participant,userId}	0	1	{string}	\N
0.12	{SecurityEvent,participant,altId}	0	1	{string}	\N
0.12	{SecurityEvent,participant,name}	0	1	{string}	\N
0.12	{SecurityEvent,participant,requestor}	1	1	{boolean}	\N
0.12	{SecurityEvent,participant,media}	0	1	{Coding}	\N
0.12	{SecurityEvent,participant,network}	0	1	{}	\N
0.12	{SecurityEvent,participant,network,extension}	0	*	{Extension}	\N
0.12	{SecurityEvent,participant,network,modifierExtension}	0	*	{Extension}	\N
0.12	{SecurityEvent,participant,network,identifier}	0	1	{string}	\N
0.12	{SecurityEvent,participant,network,type}	0	1	{code}	\N
0.12	{SecurityEvent,source}	1	1	{}	\N
0.12	{SecurityEvent,source,extension}	0	*	{Extension}	\N
0.12	{SecurityEvent,source,modifierExtension}	0	*	{Extension}	\N
0.12	{SecurityEvent,source,site}	0	1	{string}	\N
0.12	{SecurityEvent,source,identifier}	1	1	{string}	\N
0.12	{SecurityEvent,source,type}	0	*	{Coding}	\N
0.12	{SecurityEvent,object}	0	*	{}	\N
0.12	{SecurityEvent,object,extension}	0	*	{Extension}	\N
0.12	{SecurityEvent,object,modifierExtension}	0	*	{Extension}	\N
0.12	{SecurityEvent,object,identifier}	0	1	{Identifier}	\N
0.12	{SecurityEvent,object,reference}	0	1	{ResourceReference}	{Any}
0.12	{SecurityEvent,object,type}	0	1	{code}	\N
0.12	{SecurityEvent,object,role}	0	1	{code}	\N
0.12	{SecurityEvent,object,lifecycle}	0	1	{code}	\N
0.12	{SecurityEvent,object,sensitivity}	0	1	{CodeableConcept}	\N
0.12	{SecurityEvent,object,name}	0	1	{string}	\N
0.12	{SecurityEvent,object,description}	0	1	{string}	\N
0.12	{SecurityEvent,object,query}	0	1	{base64Binary}	\N
0.12	{SecurityEvent,object,detail}	0	*	{}	\N
0.12	{SecurityEvent,object,detail,extension}	0	*	{Extension}	\N
0.12	{SecurityEvent,object,detail,modifierExtension}	0	*	{Extension}	\N
0.12	{SecurityEvent,object,detail,type}	1	1	{string}	\N
0.12	{SecurityEvent,object,detail,value}	1	1	{base64Binary}	\N
0.12	{Specimen}	1	1	{Resource}	\N
0.12	{Specimen,extension}	0	*	{Extension}	\N
0.12	{Specimen,modifierExtension}	0	*	{Extension}	\N
0.12	{Specimen,text}	0	1	{Narrative}	\N
0.12	{Specimen,contained}	0	*	{Resource}	\N
0.12	{Specimen,identifier}	0	*	{Identifier}	\N
0.12	{Specimen,type}	0	1	{CodeableConcept}	\N
0.12	{Specimen,source}	0	*	{}	\N
0.12	{Specimen,source,extension}	0	*	{Extension}	\N
0.12	{Specimen,source,modifierExtension}	0	*	{Extension}	\N
0.12	{Specimen,source,relationship}	1	1	{code}	\N
0.12	{Specimen,source,target}	0	*	{ResourceReference}	{Specimen}
0.12	{Specimen,subject}	1	1	{ResourceReference,ResourceReference,ResourceReference,ResourceReference}	{Patient,Group,Device,Substance}
0.12	{Specimen,accessionIdentifier}	0	1	{Identifier}	\N
0.12	{Specimen,receivedTime}	0	1	{dateTime}	\N
0.12	{Specimen,collection}	1	1	{}	\N
0.12	{Specimen,collection,extension}	0	*	{Extension}	\N
0.12	{Specimen,collection,modifierExtension}	0	*	{Extension}	\N
0.12	{Specimen,collection,collector}	0	1	{ResourceReference}	{Practitioner}
0.12	{Specimen,collection,comment}	0	*	{string}	\N
0.12	{Specimen,collection,collected[x]}	0	1	{dateTime,Period}	\N
0.12	{Specimen,collection,quantity}	0	1	{Quantity}	\N
0.12	{Specimen,collection,method}	0	1	{CodeableConcept}	\N
0.12	{Specimen,collection,sourceSite}	0	1	{CodeableConcept}	\N
0.12	{Specimen,treatment}	0	*	{}	\N
0.12	{Specimen,treatment,extension}	0	*	{Extension}	\N
0.12	{Specimen,treatment,modifierExtension}	0	*	{Extension}	\N
0.12	{Specimen,treatment,description}	0	1	{string}	\N
0.12	{Specimen,treatment,procedure}	0	1	{CodeableConcept}	\N
0.12	{Specimen,treatment,additive}	0	*	{ResourceReference}	{Substance}
0.12	{Specimen,container}	0	*	{}	\N
0.12	{Specimen,container,extension}	0	*	{Extension}	\N
0.12	{Specimen,container,modifierExtension}	0	*	{Extension}	\N
0.12	{Specimen,container,identifier}	0	*	{Identifier}	\N
0.12	{Specimen,container,description}	0	1	{string}	\N
0.12	{Specimen,container,type}	0	1	{CodeableConcept}	\N
0.12	{Specimen,container,capacity}	0	1	{Quantity}	\N
0.12	{Specimen,container,specimenQuantity}	0	1	{Quantity}	\N
0.12	{Specimen,container,additive}	0	1	{ResourceReference}	{Substance}
0.12	{Substance}	1	1	{Resource}	\N
0.12	{Substance,extension}	0	*	{Extension}	\N
0.12	{Substance,modifierExtension}	0	*	{Extension}	\N
0.12	{Substance,text}	0	1	{Narrative}	\N
0.12	{Substance,contained}	0	*	{Resource}	\N
0.12	{Substance,type}	1	1	{CodeableConcept}	\N
0.12	{Substance,description}	0	1	{string}	\N
0.12	{Substance,instance}	0	1	{}	\N
0.12	{Substance,instance,extension}	0	*	{Extension}	\N
0.12	{Substance,instance,modifierExtension}	0	*	{Extension}	\N
0.12	{Substance,instance,identifier}	0	1	{Identifier}	\N
0.12	{Substance,instance,expiry}	0	1	{dateTime}	\N
0.12	{Substance,instance,quantity}	0	1	{Quantity}	\N
0.12	{Substance,ingredient}	0	*	{}	\N
0.12	{Substance,ingredient,extension}	0	*	{Extension}	\N
0.12	{Substance,ingredient,modifierExtension}	0	*	{Extension}	\N
0.12	{Substance,ingredient,quantity}	0	1	{Ratio}	\N
0.12	{Substance,ingredient,substance}	1	1	{ResourceReference}	{Substance}
0.12	{Supply}	1	1	{Resource}	\N
0.12	{Supply,extension}	0	*	{Extension}	\N
0.12	{Supply,modifierExtension}	0	*	{Extension}	\N
0.12	{Supply,text}	0	1	{Narrative}	\N
0.12	{Supply,contained}	0	*	{Resource}	\N
0.12	{Supply,kind}	0	1	{CodeableConcept}	\N
0.12	{Supply,identifier}	0	1	{Identifier}	\N
0.12	{Supply,status}	0	1	{code}	\N
0.12	{Supply,orderedItem}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Medication,Substance,Device}
0.12	{Supply,patient}	0	1	{ResourceReference}	{Patient}
0.12	{Supply,dispense}	0	*	{}	\N
0.12	{Supply,dispense,extension}	0	*	{Extension}	\N
0.12	{Supply,dispense,modifierExtension}	0	*	{Extension}	\N
0.12	{Supply,dispense,identifier}	0	1	{Identifier}	\N
0.12	{Supply,dispense,status}	0	1	{code}	\N
0.12	{Supply,dispense,type}	0	1	{CodeableConcept}	\N
0.12	{Supply,dispense,quantity}	0	1	{Quantity}	\N
0.12	{Supply,dispense,suppliedItem}	0	1	{ResourceReference,ResourceReference,ResourceReference}	{Medication,Substance,Device}
0.12	{Supply,dispense,supplier}	0	1	{ResourceReference}	{Practitioner}
0.12	{Supply,dispense,whenPrepared}	0	1	{Period}	\N
0.12	{Supply,dispense,whenHandedOver}	0	1	{Period}	\N
0.12	{Supply,dispense,destination}	0	1	{ResourceReference}	{Location}
0.12	{Supply,dispense,receiver}	0	*	{ResourceReference}	{Practitioner}
\.


--
-- Data for Name: resource_indexables; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY resource_indexables (param_name, resource_type, path, search_type, type, is_primitive) FROM stdin;
uid	ImagingStudy	{ImagingStudy,series,instance,uid}	token	oid	t
bodysite	DiagnosticOrder	{DiagnosticOrder,item,bodySite}	token	CodeableConcept	f
identifier	MedicationDispense	{MedicationDispense,identifier}	token	Identifier	f
diagnosis	DiagnosticReport	{DiagnosticReport,codedDiagnosis}	token	CodeableConcept	f
supersedes	DocumentManifest	{DocumentManifest,supercedes}	reference	ResourceReference	f
category	Condition	{Condition,category}	token	CodeableConcept	f
partof	Organization	{Organization,partOf}	reference	ResourceReference	f
type	Media	{Media,type}	token	code	t
subject	Media	{Media,subject}	reference	ResourceReference	f
telecom	RelatedPerson	{RelatedPerson,telecom}	string	Contact	f
value-string	Observation	{Observation,valueSampledData}	string	SampledData	f
whenprepared	MedicationDispense	{MedicationDispense,dispense,whenPrepared}	date	dateTime	t
type	SecurityEvent	{SecurityEvent,event,type}	token	CodeableConcept	f
identifier	MedicationAdministration	{MedicationAdministration,identifier}	token	Identifier	f
date	Conformance	{Conformance,date}	date	dateTime	t
source	ConceptMap	{ConceptMap,source}	reference	ResourceReference	f
prescription	MedicationAdministration	{MedicationAdministration,prescription}	reference	ResourceReference	f
phonetic	Practitioner	{Practitioner,name}	string	HumanName	f
type	Composition	{Composition,type}	token	CodeableConcept	f
type	Profile	{Profile,structure,type}	token	code	t
recipient	DocumentManifest	{DocumentManifest,recipient}	reference	ResourceReference	f
authority	Order	{Order,authority}	reference	ResourceReference	f
status	AllergyIntolerance	{AllergyIntolerance,status}	token	code	t
description	DocumentManifest	{DocumentManifest,description}	string	string	t
stage	Condition	{Condition,stage,summary}	token	CodeableConcept	f
author	DocumentManifest	{DocumentManifest,author}	reference	ResourceReference	f
encounter	Condition	{Condition,encounter}	reference	ResourceReference	f
substance	Substance	{Substance,ingredient,substance}	reference	ResourceReference	f
series	ImagingStudy	{ImagingStudy,series,uid}	token	oid	t
identifier	RelatedPerson	{RelatedPerson,identifier}	token	Identifier	f
status	Conformance	{Conformance,status}	token	code	t
type	DocumentManifest	{DocumentManifest,type}	token	CodeableConcept	f
software	Conformance	{Conformance,software,name}	string	string	t
asserter	Condition	{Condition,asserter}	reference	ResourceReference	f
type	Organization	{Organization,type}	token	CodeableConcept	f
status	ImmunizationRecommendation	{ImmunizationRecommendation,recommendation,forecastStatus}	token	CodeableConcept	f
medication	MedicationStatement	{MedicationStatement,medication}	reference	ResourceReference	f
date	Encounter	{Encounter,period}	date	Period	f
issued	DiagnosticReport	{DiagnosticReport,issued}	date	dateTime	t
event-status	DiagnosticOrder	{DiagnosticOrder,event,status}	token	code	t
subject	Immunization	{Immunization,subject}	reference	ResourceReference	f
gender	Practitioner	{Practitioner,gender}	token	CodeableConcept	f
subject	Alert	{Alert,subject}	reference	ResourceReference	f
name	RelatedPerson	{RelatedPerson,name}	string	HumanName	f
evidence	Condition	{Condition,evidence,code}	token	CodeableConcept	f
participant	CarePlan	{CarePlan,participant,member}	reference	ResourceReference	f
name	ValueSet	{ValueSet,name}	string	string	t
site	SecurityEvent	{SecurityEvent,source,site}	token	string	t
patient	Supply	{Supply,patient}	reference	ResourceReference	f
date	ImagingStudy	{ImagingStudy,dateTime}	date	dateTime	t
location	DocumentReference	{DocumentReference,location}	string	uri	t
subject	ImmunizationRecommendation	{ImmunizationRecommendation,subject}	reference	ResourceReference	f
channel	DeviceObservationReport	{DeviceObservationReport,virtualDevice,channel,code}	token	CodeableConcept	f
name	Profile	{Profile,name}	string	string	t
dependson	ConceptMap	{ConceptMap,concept,dependsOn,concept}	token	uri	t
status	Supply	{Supply,status}	token	code	t
provider	Patient	{Patient,managingOrganization}	reference	ResourceReference	f
value-string	Observation	{Observation,valueCodeableConcept}	string	CodeableConcept	f
date	ImmunizationRecommendation	{ImmunizationRecommendation,recommendation,date}	date	dateTime	t
relatesto	DocumentReference	{DocumentReference,relatesTo,target}	reference	ResourceReference	f
encounter	DiagnosticOrder	{DiagnosticOrder,encounter}	reference	ResourceReference	f
performer	DiagnosticReport	{DiagnosticReport,performer}	reference	ResourceReference	f
observation	DeviceObservationReport	{DeviceObservationReport,virtualDevice,channel,metric,observation}	reference	ResourceReference	f
manufacturer	Medication	{Medication,manufacturer}	reference	ResourceReference	f
length	Encounter	{Encounter,length}	number	Duration	f
udi	Device	{Device,udi}	string	string	t
desc	SecurityEvent	{SecurityEvent,object,name}	string	string	t
context	Composition	{Composition,event,code}	token	CodeableConcept	f
reference	SecurityEvent	{SecurityEvent,object,reference}	reference	ResourceReference	f
performer	Immunization	{Immunization,performer}	reference	ResourceReference	f
subject	Specimen	{Specimen,subject}	reference	ResourceReference	f
status	MedicationAdministration	{MedicationAdministration,status}	token	code	t
birthdate	Patient	{Patient,birthDate}	date	dateTime	t
patient	MedicationPrescription	{MedicationPrescription,patient}	reference	ResourceReference	f
when-given	MedicationStatement	{MedicationStatement,whenGiven}	date	Period	f
profile	Conformance	{Conformance,rest,resource,profile}	reference	ResourceReference	f
value-string	Observation	{Observation,valueAttachment}	string	Attachment	f
identifier	DiagnosticOrder	{DiagnosticOrder,identifier}	token	Identifier	f
medication	MedicationPrescription	{MedicationPrescription,medication}	reference	ResourceReference	f
version	ConceptMap	{ConceptMap,version}	token	string	t
dose-sequence	Immunization	{Immunization,vaccinationProtocol,doseSequence}	number	integer	t
severity	Condition	{Condition,severity}	token	CodeableConcept	f
publisher	ValueSet	{ValueSet,publisher}	string	string	t
device	MedicationStatement	{MedicationStatement,device}	reference	ResourceReference	f
subject	Condition	{Condition,subject}	reference	ResourceReference	f
author	DocumentReference	{DocumentReference,author}	reference	ResourceReference	f
value-string	Observation	{Observation,valuePeriod}	string	Period	f
action	SecurityEvent	{SecurityEvent,event,action}	token	code	t
family	Practitioner	{Practitioner,name}	string	HumanName	f
subtype	Media	{Media,subtype}	token	CodeableConcept	f
encounter	MedicationPrescription	{MedicationPrescription,encounter}	reference	ResourceReference	f
code	Medication	{Medication,code}	token	CodeableConcept	f
identifier	MedicationStatement	{MedicationStatement,identifier}	token	Identifier	f
event	Conformance	{Conformance,messaging,event,code}	token	Coding	f
status	ConceptMap	{ConceptMap,status}	token	code	t
publisher	Profile	{Profile,publisher}	string	string	t
refusal-reason	Immunization	{Immunization,explanation,refusalReason}	token	CodeableConcept	f
reference	ValueSet	{ValueSet,compose,include,system}	token	uri	t
date	Order	{Order,date}	date	dateTime	t
medication	MedicationAdministration	{MedicationAdministration,medication}	reference	ResourceReference	f
manufacturer	Device	{Device,manufacturer}	string	string	t
recorder	AllergyIntolerance	{AllergyIntolerance,recorder}	reference	ResourceReference	f
subject	Other	{Other,subject}	reference	ResourceReference	f
subject	DocumentReference	{DocumentReference,subject}	reference	ResourceReference	f
organization	Device	{Device,owner}	reference	ResourceReference	f
item-status	DiagnosticOrder	{DiagnosticOrder,item,status}	token	code	t
language	DocumentReference	{DocumentReference,primaryLanguage}	token	code	t
lot-number	Immunization	{Immunization,lotNumber}	string	string	t
identifier	Conformance	{Conformance,identifier}	token	string	t
author	Composition	{Composition,author}	reference	ResourceReference	f
patient	CarePlan	{CarePlan,patient}	reference	ResourceReference	f
expiry	Substance	{Substance,instance,expiry}	date	dateTime	t
identifier	Composition	{Composition,identifier}	token	Identifier	f
date	Observation	{Observation,appliesdateTime}	date	dateTime	t
status	DocumentReference	{DocumentReference,status}	token	code	t
active	Organization	{Organization,active}	token	boolean	t
datewritten	MedicationPrescription	{MedicationPrescription,dateWritten}	date	dateTime	t
fulfillment	OrderResponse	{OrderResponse,fulfillment}	reference	ResourceReference	f
operator	Media	{Media,operator}	reference	ResourceReference	f
system	ValueSet	{ValueSet,define,system}	token	uri	t
size	DocumentReference	{DocumentReference,size}	number	integer	t
request	DiagnosticReport	{DiagnosticReport,requestDetail}	reference	ResourceReference	f
performer	Observation	{Observation,performer}	reference	ResourceReference	f
source	DeviceObservationReport	{DeviceObservationReport,source}	reference	ResourceReference	f
address	Practitioner	{Practitioner,address}	string	Address	f
medication	MedicationDispense	{MedicationDispense,dispense,medication}	reference	ResourceReference	f
type	MedicationDispense	{MedicationDispense,dispense,type}	token	CodeableConcept	f
prescription	MedicationDispense	{MedicationDispense,authorizingPrescription}	reference	ResourceReference	f
substance	AllergyIntolerance	{AllergyIntolerance,substance}	reference	ResourceReference	f
patient	Device	{Device,patient}	reference	ResourceReference	f
reaction	Immunization	{Immunization,reaction,detail}	reference	ResourceReference	f
indication	Encounter	{Encounter,indication}	reference	ResourceReference	f
location	Device	{Device,location}	reference	ResourceReference	f
identifier	Supply	{Supply,identifier}	token	Identifier	f
view	Media	{Media,view}	token	CodeableConcept	f
altid	SecurityEvent	{SecurityEvent,participant,altId}	token	string	t
authored	Questionnaire	{Questionnaire,authored}	date	dateTime	t
identifier	ConceptMap	{ConceptMap,identifier}	token	string	t
description	Conformance	{Conformance,description}	string	string	t
service	DiagnosticReport	{DiagnosticReport,serviceCategory}	token	CodeableConcept	f
content	Medication	{Medication,package,content,item}	reference	ResourceReference	f
identifier	Questionnaire	{Questionnaire,identifier}	token	Identifier	f
identifier	Encounter	{Encounter,identifier}	token	Identifier	f
supplier	Supply	{Supply,dispense,supplier}	reference	ResourceReference	f
container	Medication	{Medication,package,container}	token	CodeableConcept	f
detail	Order	{Order,detail}	reference	ResourceReference	f
status	DocumentManifest	{DocumentManifest,status}	token	code	t
patient	RelatedPerson	{RelatedPerson,patient}	reference	ResourceReference	f
value-concept	Observation	{Observation,valueCodeableConcept}	token	CodeableConcept	f
specimen	DiagnosticReport	{DiagnosticReport,specimen}	reference	ResourceReference	f
date	AdverseReaction	{AdverseReaction,date}	date	dateTime	t
identifier	Query	{Query,identifier}	token	uri	t
confidentiality	DocumentReference	{DocumentReference,confidentiality}	token	CodeableConcept	f
dispenser	MedicationDispense	{MedicationDispense,dispenser}	reference	ResourceReference	f
code	OrderResponse	{OrderResponse,code}	token	code	t
source	List	{List,source}	reference	ResourceReference	f
destination	MedicationDispense	{MedicationDispense,dispense,destination}	reference	ResourceReference	f
exclude	Group	{Group,characteristic,exclude}	token	boolean	t
version	Conformance	{Conformance,version}	token	string	t
modality	ImagingStudy	{ImagingStudy,series,modality}	token	code	t
name	Patient	{Patient,name}	string	HumanName	f
onset	Condition	{Condition,onsetdate}	date	date	t
name	Location	{Location,name}	string	string	t
date	ConceptMap	{ConceptMap,date}	date	dateTime	t
code	Condition	{Condition,code}	token	CodeableConcept	f
subject	FamilyHistory	{FamilyHistory,subject}	reference	ResourceReference	f
description	ConceptMap	{ConceptMap,description}	string	string	t
date	OrderResponse	{OrderResponse,date}	date	dateTime	t
partof	Location	{Location,partOf}	reference	ResourceReference	f
name	Observation	{Observation,name}	token	CodeableConcept	f
device	MedicationAdministration	{MedicationAdministration,device}	reference	ResourceReference	f
date	AllergyIntolerance	{AllergyIntolerance,recordedDate}	date	dateTime	t
created	DocumentManifest	{DocumentManifest,created}	date	dateTime	t
name	Questionnaire	{Questionnaire,name}	token	CodeableConcept	f
type	Group	{Group,type}	token	code	t
date	DiagnosticReport	{DiagnosticReport,diagnosticdateTime}	date	dateTime	t
identifier	Patient	{Patient,identifier}	token	Identifier	f
related-type	Observation	{Observation,related,type}	token	code	t
accession	ImagingStudy	{ImagingStudy,accessionNo}	token	Identifier	f
animal-species	Patient	{Patient,animal,species}	token	CodeableConcept	f
information	ImmunizationRecommendation	{ImmunizationRecommendation,recommendation,supportingPatientInformation}	reference	ResourceReference	f
encounter	Questionnaire	{Questionnaire,encounter}	reference	ResourceReference	f
requester	Immunization	{Immunization,requester}	reference	ResourceReference	f
source	Order	{Order,source}	reference	ResourceReference	f
subject	DiagnosticReport	{DiagnosticReport,subject}	reference	ResourceReference	f
type	Procedure	{Procedure,type}	token	CodeableConcept	f
telecom	Patient	{Patient,telecom}	string	Contact	f
code	DeviceObservationReport	{DeviceObservationReport,virtualDevice,code}	token	CodeableConcept	f
identity	SecurityEvent	{SecurityEvent,object,identifier}	token	Identifier	f
name	ConceptMap	{ConceptMap,name}	string	string	t
location	Immunization	{Immunization,location}	reference	ResourceReference	f
form	Medication	{Medication,product,form}	token	CodeableConcept	f
organization	Practitioner	{Practitioner,organization}	reference	ResourceReference	f
party	Provenance	{Provenance,agent,reference}	token	uri	t
subject	DiagnosticOrder	{DiagnosticOrder,subject}	reference	ResourceReference	f
type	Location	{Location,type}	token	CodeableConcept	f
code	Other	{Other,code}	token	CodeableConcept	f
subject	Procedure	{Procedure,subject}	reference	ResourceReference	f
refused	Immunization	{Immunization,refusedIndicator}	token	boolean	t
date	Composition	{Composition,date}	date	dateTime	t
created	Other	{Other,created}	date	date	t
support	ImmunizationRecommendation	{ImmunizationRecommendation,recommendation,supportingImmunization}	reference	ResourceReference	f
status	MedicationDispense	{MedicationDispense,dispense,status}	token	code	t
activitydetail	CarePlan	{CarePlan,activity,detail}	reference	ResourceReference	f
active	Patient	{Patient,active}	token	boolean	t
publisher	Conformance	{Conformance,publisher}	string	string	t
name	Organization	{Organization,name}	string	string	t
class	Composition	{Composition,class}	token	CodeableConcept	f
section-type	Composition	{Composition,section,code}	token	CodeableConcept	f
identifier	Profile	{Profile,identifier}	token	string	t
when	Order	{Order,when,schedule}	date	Schedule	f
status	DiagnosticOrder	{DiagnosticOrder,status}	token	code	t
whengiven	MedicationAdministration	{MedicationAdministration,whenGiven}	date	Period	f
request	OrderResponse	{OrderResponse,request}	reference	ResourceReference	f
date	List	{List,date}	date	dateTime	t
date	Procedure	{Procedure,date}	date	Period	f
patient	MedicationAdministration	{MedicationAdministration,patient}	reference	ResourceReference	f
gender	Patient	{Patient,gender}	token	CodeableConcept	f
result	DiagnosticReport	{DiagnosticReport,result}	reference	ResourceReference	f
characteristic	Group	{Group,characteristic,code}	token	CodeableConcept	f
who	OrderResponse	{OrderResponse,who}	reference	ResourceReference	f
object-type	SecurityEvent	{SecurityEvent,object,type}	token	code	t
identifier	ImmunizationRecommendation	{ImmunizationRecommendation,identifier}	token	Identifier	f
version	ValueSet	{ValueSet,version}	token	string	t
encounter	MedicationAdministration	{MedicationAdministration,encounter}	reference	ResourceReference	f
type	Device	{Device,type}	token	CodeableConcept	f
end	Provenance	{Provenance,period,end}	date	dateTime	t
patient	MedicationDispense	{MedicationDispense,patient}	reference	ResourceReference	f
event-date	DiagnosticOrder	{DiagnosticOrder,event,dateTime}	date	dateTime	t
substance	AdverseReaction	{AdverseReaction,exposure,substance}	reference	ResourceReference	f
name	SecurityEvent	{SecurityEvent,participant,name}	string	string	t
user	SecurityEvent	{SecurityEvent,participant,userId}	token	string	t
resource	Conformance	{Conformance,rest,resource,type}	token	code	t
quantity	Substance	{Substance,instance,quantity}	number	Quantity	f
date	Observation	{Observation,appliesPeriod}	date	Period	f
content	DocumentManifest	{DocumentManifest,content}	reference	ResourceReference	f
code	List	{List,code}	token	CodeableConcept	f
reliability	Observation	{Observation,reliability}	token	code	t
format	Conformance	{Conformance,format}	token	code	t
status	Location	{Location,status}	token	code	t
image	DiagnosticReport	{DiagnosticReport,image,link}	reference	ResourceReference	f
empty-reason	List	{List,emptyReason}	token	CodeableConcept	f
condition	CarePlan	{CarePlan,concern}	reference	ResourceReference	f
value-string	Observation	{Observation,valueQuantity}	string	Quantity	f
activitydate	CarePlan	{CarePlan,activity,simple,timingPeriod}	date	Period	f
specimen	Observation	{Observation,specimen}	reference	ResourceReference	f
description	Profile	{Profile,description}	string	string	t
study	ImagingStudy	{ImagingStudy,uid}	token	oid	t
identifier	MedicationPrescription	{MedicationPrescription,identifier}	token	Identifier	f
value-date	Observation	{Observation,valuePeriod}	date	Period	f
date	Immunization	{Immunization,date}	date	dateTime	t
type	AllergyIntolerance	{AllergyIntolerance,sensitivityType}	token	code	t
version	Profile	{Profile,version}	token	string	t
date	CarePlan	{CarePlan,period}	date	Period	f
value-quantity	Observation	{Observation,valueQuantity}	quantity	Quantity	f
animal-breed	Patient	{Patient,animal,breed}	token	CodeableConcept	f
identifier	Immunization	{Immunization,identifier}	token	Identifier	f
response	Query	{Query,response,identifier}	token	uri	t
status	MedicationPrescription	{MedicationPrescription,status}	token	code	t
responsibleparty	MedicationDispense	{MedicationDispense,substitution,responsibleParty}	reference	ResourceReference	f
bodysite	ImagingStudy	{ImagingStudy,series,bodySite}	token	Coding	f
mode	Conformance	{Conformance,rest,mode}	token	code	t
authenticator	DocumentReference	{DocumentReference,authenticator}	reference	ResourceReference	f
event	DocumentReference	{DocumentReference,context,event}	token	CodeableConcept	f
dose-number	ImmunizationRecommendation	{ImmunizationRecommendation,recommendation,doseNumber}	number	integer	t
related-target	Observation	{Observation,related,target}	reference	ResourceReference	f
code	Group	{Group,code}	token	CodeableConcept	f
activitycode	CarePlan	{CarePlan,activity,simple,code}	token	CodeableConcept	f
address	SecurityEvent	{SecurityEvent,participant,network,identifier}	token	string	t
address	RelatedPerson	{RelatedPerson,address}	string	Address	f
code	ValueSet	{ValueSet,define,concept,code}	token	code	t
author	Questionnaire	{Questionnaire,author}	reference	ResourceReference	f
date	DiagnosticReport	{DiagnosticReport,diagnosticPeriod}	date	Period	f
description	DocumentReference	{DocumentReference,description}	string	string	t
actual	Group	{Group,actual}	token	boolean	t
target	Order	{Order,target}	reference	ResourceReference	f
identifier	Media	{Media,identifier}	token	Identifier	f
type	DocumentReference	{DocumentReference,type}	token	CodeableConcept	f
target	Provenance	{Provenance,target}	reference	ResourceReference	f
relation	DocumentReference	{DocumentReference,relatesTo,code}	token	code	t
value-string	Observation	{Observation,valuestring}	string	string	t
dicom-class	ImagingStudy	{ImagingStudy,series,instance,sopclass}	token	oid	t
related-item	Condition	{Condition,relatedItem,target}	reference	ResourceReference	f
date	ValueSet	{ValueSet,date}	date	dateTime	t
identifier	Organization	{Organization,identifier}	token	Identifier	f
model	Device	{Device,model}	string	string	t
ingredient	Medication	{Medication,product,ingredient,item}	reference	ResourceReference	f
activitydate	CarePlan	{CarePlan,activity,simple,timingSchedule}	date	Schedule	f
subject	Questionnaire	{Questionnaire,subject}	reference	ResourceReference	f
system	ConceptMap	{ConceptMap,concept,map,system}	token	uri	t
location	Provenance	{Provenance,location}	reference	ResourceReference	f
identifier	DiagnosticReport	{DiagnosticReport,identifier}	token	Identifier	f
status	Observation	{Observation,status}	token	code	t
identifier	Group	{Group,identifier}	token	Identifier	f
item	List	{List,entry,item}	reference	ResourceReference	f
identifier	Device	{Device,identifier}	token	Identifier	f
attester	Composition	{Composition,attester,party}	reference	ResourceReference	f
identifier	Substance	{Substance,instance,identifier}	token	Identifier	f
date-asserted	Condition	{Condition,dateAsserted}	date	date	t
date	Media	{Media,dateTime}	date	dateTime	t
partytype	Provenance	{Provenance,agent,type}	token	Coding	f
subject	Observation	{Observation,subject}	reference	ResourceReference	f
orderer	DiagnosticOrder	{DiagnosticOrder,orderer}	reference	ResourceReference	f
source	SecurityEvent	{SecurityEvent,source,identifier}	token	string	t
supported-profile	Conformance	{Conformance,profile}	reference	ResourceReference	f
custodian	DocumentReference	{DocumentReference,custodian}	reference	ResourceReference	f
reaction-date	Immunization	{Immunization,reaction,date}	date	dateTime	t
given	Practitioner	{Practitioner,name}	string	HumanName	f
target	ConceptMap	{ConceptMap,target}	reference	ResourceReference	f
confidentiality	DocumentManifest	{DocumentManifest,confidentiality}	token	CodeableConcept	f
value	Group	{Group,characteristic,valueboolean}	token	boolean	t
code	DiagnosticOrder	{DiagnosticOrder,item,code}	token	CodeableConcept	f
status	Encounter	{Encounter,status}	token	code	t
format	DocumentReference	{DocumentReference,format}	token	uri	t
status	Profile	{Profile,status}	token	code	t
location	Encounter	{Encounter,location,location}	reference	ResourceReference	f
address	Patient	{Patient,address}	string	Address	f
status	Questionnaire	{Questionnaire,status}	token	code	t
created	DocumentReference	{DocumentReference,created}	date	dateTime	t
identifier	Location	{Location,identifier}	token	Identifier	f
vaccine-type	ImmunizationRecommendation	{ImmunizationRecommendation,recommendation,vaccineType}	token	CodeableConcept	f
name	Conformance	{Conformance,name}	string	string	t
subject	AdverseReaction	{AdverseReaction,subject}	reference	ResourceReference	f
name	DiagnosticReport	{DiagnosticReport,name}	token	CodeableConcept	f
description	ValueSet	{ValueSet,description}	string	string	t
valueset	Profile	{Profile,structure,element,definition,binding,referenceResourceReference}	reference	ResourceReference	f
date	Profile	{Profile,date}	date	dateTime	t
symptom	AdverseReaction	{AdverseReaction,symptom,code}	token	CodeableConcept	f
subject	Encounter	{Encounter,subject}	reference	ResourceReference	f
whenhandedover	MedicationDispense	{MedicationDispense,dispense,whenHandedOver}	date	dateTime	t
subject	DeviceObservationReport	{DeviceObservationReport,subject}	reference	ResourceReference	f
subject	AllergyIntolerance	{AllergyIntolerance,subject}	reference	ResourceReference	f
related-code	Condition	{Condition,relatedItem,code}	token	CodeableConcept	f
location	Condition	{Condition,location,code}	token	CodeableConcept	f
reason	Immunization	{Immunization,explanation,reason}	token	CodeableConcept	f
language	Patient	{Patient,communication}	token	CodeableConcept	f
patient	MedicationStatement	{MedicationStatement,patient}	reference	ResourceReference	f
kind	Supply	{Supply,kind}	token	CodeableConcept	f
class	DocumentReference	{DocumentReference,class}	token	CodeableConcept	f
code	Profile	{Profile,code}	token	Coding	f
vaccine-type	Immunization	{Immunization,vaccineType}	token	CodeableConcept	f
manufacturer	Immunization	{Immunization,manufacturer}	reference	ResourceReference	f
when_code	Order	{Order,when,code}	token	CodeableConcept	f
link	Patient	{Patient,link,other}	reference	ResourceReference	f
publisher	ConceptMap	{ConceptMap,publisher}	string	string	t
indexed	DocumentReference	{DocumentReference,indexed}	date	instant	t
subject	ImagingStudy	{ImagingStudy,subject}	reference	ResourceReference	f
value	Group	{Group,characteristic,valueCodeableConcept}	token	CodeableConcept	f
type	Substance	{Substance,type}	token	CodeableConcept	f
subtype	SecurityEvent	{SecurityEvent,event,subtype}	token	CodeableConcept	f
period	DocumentReference	{DocumentReference,context,period}	date	Period	f
facility	DocumentReference	{DocumentReference,context,facilityType}	token	CodeableConcept	f
subject	DocumentManifest	{DocumentManifest,subject}	reference	ResourceReference	f
subject	List	{List,subject}	reference	ResourceReference	f
notgiven	MedicationAdministration	{MedicationAdministration,wasNotGiven}	token	boolean	t
value-string	Observation	{Observation,valueRatio}	string	Ratio	f
status	ValueSet	{ValueSet,status}	token	code	t
fhirversion	Conformance	{Conformance,version}	token	string	t
telecom	Practitioner	{Practitioner,telecom}	string	Contact	f
product	ConceptMap	{ConceptMap,concept,map,product,concept}	token	uri	t
section-content	Composition	{Composition,section,content}	reference	ResourceReference	f
identifier	Practitioner	{Practitioner,identifier}	token	Identifier	f
location-period	Encounter	{Encounter,location,period}	date	Period	f
extension	Profile	{Profile,extensionDefn,code}	token	code	t
item-past-status	DiagnosticOrder	{DiagnosticOrder,item,event,status}	token	code	t
given	Patient	{Patient,name,given}	string	string	t
value-concept	Observation	{Observation,valuestring}	token	string	t
member	Group	{Group,member}	reference	ResourceReference	f
status	DiagnosticReport	{DiagnosticReport,status}	token	code	t
dispensestatus	Supply	{Supply,dispense,status}	token	code	t
status	Condition	{Condition,status}	token	code	t
name	Medication	{Medication,name}	string	string	t
gender	RelatedPerson	{RelatedPerson,gender}	token	CodeableConcept	f
name	Practitioner	{Practitioner,name}	string	HumanName	f
subject	Composition	{Composition,subject}	reference	ResourceReference	f
date	SecurityEvent	{SecurityEvent,event,dateTime}	date	instant	t
identifier	ValueSet	{ValueSet,identifier}	token	string	t
subject	Order	{Order,subject}	reference	ResourceReference	f
address	Location	{Location,address}	string	Address	f
dispenseid	Supply	{Supply,dispense,identifier}	token	Identifier	f
family	Patient	{Patient,name,family}	string	string	t
_id	Media	{Media,_id}	identifier	uuid	t
_id	Substance	{Substance,_id}	identifier	uuid	t
_id	Questionnaire	{Questionnaire,_id}	identifier	uuid	t
_id	Procedure	{Procedure,_id}	identifier	uuid	t
_id	DocumentReference	{DocumentReference,_id}	identifier	uuid	t
_id	SecurityEvent	{SecurityEvent,_id}	identifier	uuid	t
_id	AdverseReaction	{AdverseReaction,_id}	identifier	uuid	t
_id	Composition	{Composition,_id}	identifier	uuid	t
_id	Immunization	{Immunization,_id}	identifier	uuid	t
_id	CarePlan	{CarePlan,_id}	identifier	uuid	t
_id	DiagnosticOrder	{DiagnosticOrder,_id}	identifier	uuid	t
_id	ValueSet	{ValueSet,_id}	identifier	uuid	t
_id	Medication	{Medication,_id}	identifier	uuid	t
_id	Provenance	{Provenance,_id}	identifier	uuid	t
_id	List	{List,_id}	identifier	uuid	t
_id	OrderResponse	{OrderResponse,_id}	identifier	uuid	t
_id	RelatedPerson	{RelatedPerson,_id}	identifier	uuid	t
_id	Location	{Location,_id}	identifier	uuid	t
_id	Condition	{Condition,_id}	identifier	uuid	t
_id	Profile	{Profile,_id}	identifier	uuid	t
_id	Device	{Device,_id}	identifier	uuid	t
_id	Encounter	{Encounter,_id}	identifier	uuid	t
_id	Supply	{Supply,_id}	identifier	uuid	t
_id	Conformance	{Conformance,_id}	identifier	uuid	t
_id	Observation	{Observation,_id}	identifier	uuid	t
_id	FamilyHistory	{FamilyHistory,_id}	identifier	uuid	t
_id	ImagingStudy	{ImagingStudy,_id}	identifier	uuid	t
_id	AllergyIntolerance	{AllergyIntolerance,_id}	identifier	uuid	t
_id	DeviceObservationReport	{DeviceObservationReport,_id}	identifier	uuid	t
_id	Specimen	{Specimen,_id}	identifier	uuid	t
_id	Group	{Group,_id}	identifier	uuid	t
_id	Query	{Query,_id}	identifier	uuid	t
_id	DiagnosticReport	{DiagnosticReport,_id}	identifier	uuid	t
_id	Order	{Order,_id}	identifier	uuid	t
_id	DocumentManifest	{DocumentManifest,_id}	identifier	uuid	t
_id	Other	{Other,_id}	identifier	uuid	t
_id	ImmunizationRecommendation	{ImmunizationRecommendation,_id}	identifier	uuid	t
_id	Organization	{Organization,_id}	identifier	uuid	t
_id	MedicationStatement	{MedicationStatement,_id}	identifier	uuid	t
_id	Practitioner	{Practitioner,_id}	identifier	uuid	t
_id	Alert	{Alert,_id}	identifier	uuid	t
_id	MedicationDispense	{MedicationDispense,_id}	identifier	uuid	t
_id	MedicationPrescription	{MedicationPrescription,_id}	identifier	uuid	t
_id	MedicationAdministration	{MedicationAdministration,_id}	identifier	uuid	t
_id	ConceptMap	{ConceptMap,_id}	identifier	uuid	t
_id	Patient	{Patient,_id}	identifier	uuid	t
\.


--
-- Data for Name: resource_search_params; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY resource_search_params (_id, path, name, version, type, documentation) FROM stdin;
1	{ValueSet}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
2	{ValueSet,define,concept,code}	code	0.12	token	A code defined in the value set
3	{ValueSet,date}	date	0.12	date	The value set publication date
4	{ValueSet,description}	description	0.12	string	Text search in the description of the value set
5	{ValueSet,identifier}	identifier	0.12	token	The identifier of the value set
6	{ValueSet,name}	name	0.12	string	The name of the value set
7	{ValueSet,publisher}	publisher	0.12	string	Name of the publisher of the value set
8	{ValueSet,compose,include,system}	reference	0.12	token	A code system included or excluded in the value set or an imported value set
9	{ValueSet,status}	status	0.12	token	The status of the value set
10	{ValueSet,define,system}	system	0.12	token	The system for any codes defined by this value set
11	{ValueSet,version}	version	0.12	token	The version identifier of the value set
12	{AdverseReaction}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
13	{AdverseReaction,date}	date	0.12	date	The date of the reaction
14	{AdverseReaction,subject}	subject	0.12	reference	The subject that the sensitivity is about
15	{AdverseReaction,exposure,substance}	substance	0.12	reference	The name or code of the substance that produces the sensitivity
16	{AdverseReaction,symptom,code}	symptom	0.12	token	One of the symptoms of the reaction
17	{Alert}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
18	{Alert,subject}	subject	0.12	reference	The identity of a subject to list alerts for
19	{AllergyIntolerance}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
20	{AllergyIntolerance,recordedDate}	date	0.12	date	Recorded date/time.
21	{AllergyIntolerance,recorder}	recorder	0.12	reference	Who recorded the sensitivity
22	{AllergyIntolerance,status}	status	0.12	token	The status of the sensitivity
23	{AllergyIntolerance,subject}	subject	0.12	reference	The subject that the sensitivity is about
24	{AllergyIntolerance,substance}	substance	0.12	reference	The name or code of the substance that produces the sensitivity
25	{AllergyIntolerance,sensitivityType}	type	0.12	token	The type of sensitivity
26	{CarePlan}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
27	{CarePlan,activity,simple,code}	activitycode	0.12	token	Detail type of activity
28	{CarePlan,activity,simple,timing[x]}	activitydate	0.12	date	Specified date occurs within period specified by CarePlan.activity.timingSchedule
29	{CarePlan,activity,detail}	activitydetail	0.12	reference	Activity details defined in specific resource
30	{CarePlan,concern}	condition	0.12	reference	Health issues this plan addresses
31	{CarePlan,period}	date	0.12	date	Time period plan covers
32	{CarePlan,participant,member}	participant	0.12	reference	Who is involved
33	{CarePlan,patient}	patient	0.12	reference	Who care plan is for
34	{Composition}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
35	{Composition,attester,party}	attester	0.12	reference	Who attested the composition
36	{Composition,author}	author	0.12	reference	Who and/or what authored the composition
37	{Composition,class}	class	0.12	token	Categorization of Composition
38	{Composition,event,code}	context	0.12	token	Code(s) that apply to the event being documented
39	{Composition,date}	date	0.12	date	Composition editing time
40	{Composition,identifier}	identifier	0.12	token	Logical identifier of composition (version-independent)
41	{Composition,section,content}	section-content	0.12	reference	The actual data for the section
42	{Composition,section,code}	section-type	0.12	token	Classification of section (recommended)
43	{Composition,subject}	subject	0.12	reference	Who and/or what the composition is about
44	{Composition,type}	type	0.12	token	Kind of composition (LOINC if possible)
45	{ConceptMap}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
46	{ConceptMap,date}	date	0.12	date	The concept map publication date
47	{ConceptMap,concept,dependsOn,concept}	dependson	0.12	token	Reference to element/field/valueset provides the context
48	{ConceptMap,description}	description	0.12	string	Text search in the description of the concept map
49	{ConceptMap,identifier}	identifier	0.12	token	The identifier of the concept map
50	{ConceptMap,name}	name	0.12	string	Name of the concept map
51	{ConceptMap,concept,map,product,concept}	product	0.12	token	Reference to element/field/valueset provides the context
52	{ConceptMap,publisher}	publisher	0.12	string	Name of the publisher of the concept map
53	{ConceptMap,source}	source	0.12	reference	The system for any concepts mapped by this concept map
54	{ConceptMap,status}	status	0.12	token	Status of the concept map
55	{ConceptMap,concept,map,system}	system	0.12	token	The system for any destination concepts mapped by this map
56	{ConceptMap,target}	target	0.12	reference	Provides context to the mappings
57	{ConceptMap,version}	version	0.12	token	The version identifier of the concept map
58	{Condition}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
59	{Condition,asserter}	asserter	0.12	reference	Person who asserts this condition
60	{Condition,category}	category	0.12	token	The category of the condition
61	{Condition,code}	code	0.12	token	Code for the condition
62	{Condition,dateAsserted}	date-asserted	0.12	date	When first detected/suspected/entered
63	{Condition,encounter}	encounter	0.12	reference	Encounter when condition first asserted
64	{Condition,evidence,code}	evidence	0.12	token	Manifestation/symptom
65	{Condition,location,code}	location	0.12	token	Location - may include laterality
66	{Condition,onset[x]}	onset	0.12	date	When the Condition started (if started on a date)
67	{Condition,relatedItem,code}	related-code	0.12	token	Relationship target by means of a predefined code
68	{Condition,relatedItem,target}	related-item	0.12	reference	Relationship target resource
69	{Condition,severity}	severity	0.12	token	The severity of the condition
70	{Condition,stage,summary}	stage	0.12	token	Simple summary (disease specific)
71	{Condition,status}	status	0.12	token	The status of the condition
72	{Condition,subject}	subject	0.12	reference	Who has the condition?
73	{Conformance}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
74	{Conformance,date}	date	0.12	date	The conformance statement publication date
75	{Conformance,description}	description	0.12	string	Text search in the description of the conformance statement
76	{Conformance,messaging,event,code}	event	0.12	token	Event code in a conformance statement
77	{Conformance,version}	fhirversion	0.12	token	The version of FHIR
78	{Conformance,format}	format	0.12	token	formats supported (xml | json | mime type)
79	{Conformance,identifier}	identifier	0.12	token	The identifier of the conformance statement
80	{Conformance,rest,mode}	mode	0.12	token	Mode - restful (server/client) or messaging (sender/receiver)
81	{Conformance,name}	name	0.12	string	Name of the conformance statement
82	{Conformance,rest,resource,profile}	profile	0.12	reference	A profile id invoked in a conformance statement
83	{Conformance,publisher}	publisher	0.12	string	Name of the publisher of the conformance statement
84	{Conformance,rest,resource,type}	resource	0.12	token	Name of a resource mentioned in a conformance statement
85	{Conformance,rest,security}	security	0.12	token	Information about security of implementation
86	{Conformance,software,name}	software	0.12	string	Part of a the name of a software application
87	{Conformance,status}	status	0.12	token	The current status of the conformance statement
88	{Conformance,profile}	supported-profile	0.12	reference	Profiles supported by the system
89	{Conformance,version}	version	0.12	token	The version identifier of the conformance statement
90	{Device}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
91	{Device,identifier}	identifier	0.12	token	Instance id from manufacturer, owner and others
92	{Device,location}	location	0.12	reference	A location, where the resource is found
93	{Device,manufacturer}	manufacturer	0.12	string	The manufacturer of the device
94	{Device,model}	model	0.12	string	The model of the device
95	{Device,owner}	organization	0.12	reference	The organization responsible for the device
96	{Device,patient}	patient	0.12	reference	Patient information, if the resource is affixed to a person
97	{Device,type}	type	0.12	token	The type of the device
98	{Device,udi}	udi	0.12	string	FDA Mandated Unique Device Identifier
99	{DeviceObservationReport}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
100	{DeviceObservationReport,virtualDevice,channel,code}	channel	0.12	token	The channel code
101	{DeviceObservationReport,virtualDevice,code}	code	0.12	token	The compatment code
102	{DeviceObservationReport,virtualDevice,channel,metric,observation}	observation	0.12	reference	The data for the metric
103	{DeviceObservationReport,source}	source	0.12	reference	Identifies/describes where the data came from
104	{DeviceObservationReport,subject}	subject	0.12	reference	Subject of the measurement
105	{DiagnosticOrder}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
106	{DiagnosticOrder}	actor	0.12	reference	Who recorded or did this
107	{DiagnosticOrder,item,bodySite}	bodysite	0.12	token	Location of requested test (if applicable)
108	{DiagnosticOrder,item,code}	code	0.12	token	Code to indicate the item (test or panel) being ordered
109	{DiagnosticOrder,encounter}	encounter	0.12	reference	The encounter that this diagnostic order is associated with
110	{DiagnosticOrder,event,dateTime}	event-date	0.12	date	The date at which the event happened
111	{DiagnosticOrder,event,status}	event-status	0.12	token	requested | received | accepted | in progress | review | completed | suspended | rejected | failed
112	{DiagnosticOrder}	event-status-date	0.12	composite	A combination of past-status and date
113	{DiagnosticOrder,identifier}	identifier	0.12	token	Identifiers assigned to this order
114	{DiagnosticOrder,item,event,dateTime}	item-date	0.12	date	The date at which the event happened
115	{DiagnosticOrder,item,event,status}	item-past-status	0.12	token	requested | received | accepted | in progress | review | completed | suspended | rejected | failed
116	{DiagnosticOrder,item,status}	item-status	0.12	token	requested | received | accepted | in progress | review | completed | suspended | rejected | failed
117	{DiagnosticOrder}	item-status-date	0.12	composite	A combination of item-past-status and item-date
118	{DiagnosticOrder,orderer}	orderer	0.12	reference	Who ordered the test
119	{DiagnosticOrder}	specimen	0.12	reference	If the whole order relates to specific specimens
120	{DiagnosticOrder,status}	status	0.12	token	requested | received | accepted | in progress | review | completed | suspended | rejected | failed
121	{DiagnosticOrder,subject}	subject	0.12	reference	Who and/or what test is about
122	{DiagnosticReport}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
123	{DiagnosticReport,diagnostic[x]}	date	0.12	date	The clinically relevant time of the report
124	{DiagnosticReport,codedDiagnosis}	diagnosis	0.12	token	A coded diagnosis on the report
125	{DiagnosticReport,identifier}	identifier	0.12	token	An identifier for the report
126	{DiagnosticReport,image,link}	image	0.12	reference	Reference to the image source
127	{DiagnosticReport,issued}	issued	0.12	date	When the report was issued
128	{DiagnosticReport,name}	name	0.12	token	The name of the report (e.g. the code for the report as a whole, as opposed to codes for the atomic results, which are the names on the observation resource referred to from the result)
129	{DiagnosticReport,performer}	performer	0.12	reference	Who was the source of the report (organization)
130	{DiagnosticReport,requestDetail}	request	0.12	reference	What was requested
131	{DiagnosticReport,result}	result	0.12	reference	Link to an atomic result (observation resource)
132	{DiagnosticReport,serviceCategory}	service	0.12	token	Which diagnostic discipline/department created the report
133	{DiagnosticReport,specimen}	specimen	0.12	reference	The specimen details
134	{DiagnosticReport,status}	status	0.12	token	The status of the report
135	{DiagnosticReport,subject}	subject	0.12	reference	The subject of the report
136	{DocumentManifest}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
137	{DocumentManifest,author}	author	0.12	reference	Who and/or what authored the document
138	{DocumentManifest,confidentiality}	confidentiality	0.12	token	Sensitivity of set of documents
139	{DocumentManifest,content}	content	0.12	reference	Contents of this set of documents
140	{DocumentManifest,created}	created	0.12	date	When this document manifest created
141	{DocumentManifest,description}	description	0.12	string	Human-readable description (title)
142	{DocumentManifest}	identifier	0.12	token	Unique Identifier for the set of documents
143	{DocumentManifest,recipient}	recipient	0.12	reference	Intended to get notified about this set of documents
144	{DocumentManifest,status}	status	0.12	token	current | superceded | entered in error
145	{DocumentManifest,subject}	subject	0.12	reference	The subject of the set of documents
146	{DocumentManifest,supercedes}	supersedes	0.12	reference	If this document manifest replaces another
147	{DocumentManifest,type}	type	0.12	token	What kind of document set this is
148	{DocumentReference}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
149	{DocumentReference,authenticator}	authenticator	0.12	reference	Who/What authenticated the document
150	{DocumentReference,author}	author	0.12	reference	Who and/or what authored the document
151	{DocumentReference,class}	class	0.12	token	Categorization of Document
152	{DocumentReference,confidentiality}	confidentiality	0.12	token	Sensitivity of source document
153	{DocumentReference,created}	created	0.12	date	Document creation time
154	{DocumentReference,custodian}	custodian	0.12	reference	Org which maintains the document
155	{DocumentReference,description}	description	0.12	string	Human-readable description (title)
156	{DocumentReference,context,event}	event	0.12	token	Main Clinical Acts Documented
157	{DocumentReference,context,facilityType}	facility	0.12	token	Kind of facility where patient was seen
158	{DocumentReference,format}	format	0.12	token	Format/content rules for the document
159	{DocumentReference}	identifier	0.12	token	Master Version Specific Identifier
160	{DocumentReference,indexed}	indexed	0.12	date	When this document reference created
161	{DocumentReference,primaryLanguage}	language	0.12	token	The marked primary language for the document
162	{DocumentReference,location}	location	0.12	string	Where to access the document
163	{DocumentReference,context,period}	period	0.12	date	Time of service that is being documented
164	{DocumentReference,relatesTo,target}	relatesto	0.12	reference	Target of the relationship
165	{DocumentReference,relatesTo,code}	relation	0.12	token	replaces | transforms | signs | appends
166	{DocumentReference}	relationship	0.12	composite	Combination of relation and relatesTo
167	{DocumentReference,size}	size	0.12	number	Size of the document in bytes
168	{DocumentReference,status}	status	0.12	token	current | superceded | entered in error
169	{DocumentReference,subject}	subject	0.12	reference	Who|what is the subject of the document
170	{DocumentReference,type}	type	0.12	token	What kind of document this is (LOINC if possible)
171	{Encounter}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
172	{Encounter,period}	date	0.12	date	A date within the period the Encounter lasted
173	{Encounter,identifier}	identifier	0.12	token	Identifier(s) by which this encounter is known
174	{Encounter,indication}	indication	0.12	reference	Reason the encounter takes place (resource)
175	{Encounter,length}	length	0.12	number	Length of encounter in days
176	{Encounter,location,location}	location	0.12	reference	Location the encounter takes place
177	{Encounter,location,period}	location-period	0.12	date	Time period during which the patient was present at the location
178	{Encounter,status}	status	0.12	token	planned | in progress | onleave | finished | cancelled
179	{Encounter,subject}	subject	0.12	reference	The patient present at the encounter
180	{FamilyHistory}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
181	{FamilyHistory,subject}	subject	0.12	reference	The identity of a subject to list family history items for
182	{Group}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
183	{Group,actual}	actual	0.12	token	Descriptive or actual
184	{Group,characteristic,code}	characteristic	0.12	token	Kind of characteristic
185	{Group}	characteristic-value	0.12	composite	A composite of both characteristic and value
186	{Group,code}	code	0.12	token	The kind of resources contained
187	{Group,characteristic,exclude}	exclude	0.12	token	Group includes or excludes
188	{Group,identifier}	identifier	0.12	token	Unique id
189	{Group,member}	member	0.12	reference	Who is in group
190	{Group,type}	type	0.12	token	The type of resources the group contains
191	{Group,characteristic,value[x]}	value	0.12	token	Value held by characteristic
192	{ImagingStudy}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
193	{ImagingStudy,accessionNo}	accession	0.12	token	The accession id for the image
194	{ImagingStudy,series,bodySite}	bodysite	0.12	token	Body part examined (Map from 0018,0015)
195	{ImagingStudy,dateTime}	date	0.12	date	The date the study was done was taken
196	{ImagingStudy,series,instance,sopclass}	dicom-class	0.12	token	DICOM class type (0008,0016)
197	{ImagingStudy,series,modality}	modality	0.12	token	The modality of the image
198	{ImagingStudy,series,uid}	series	0.12	token	The series id for the image
199	{ImagingStudy}	size	0.12	number	The size of the image in MB - may include &gt; or &lt; in the value
200	{ImagingStudy,uid}	study	0.12	token	The study id for the image
201	{ImagingStudy,subject}	subject	0.12	reference	Who the study is about
202	{ImagingStudy,series,instance,uid}	uid	0.12	token	Formal identifier for this instance (0008,0018)
203	{Immunization}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
204	{Immunization,date}	date	0.12	date	Vaccination  Administration / Refusal Date
205	{Immunization,vaccinationProtocol,doseSequence}	dose-sequence	0.12	number	What dose number within series?
206	{Immunization,identifier}	identifier	0.12	token	Business identifier
207	{Immunization,location}	location	0.12	reference	The service delivery location or facility in which the vaccine was / was to be administered
208	{Immunization,lotNumber}	lot-number	0.12	string	Vaccine Lot Number
209	{Immunization,manufacturer}	manufacturer	0.12	reference	Vaccine Manufacturer
210	{Immunization,performer}	performer	0.12	reference	The practitioner who administered the vaccination
211	{Immunization,reaction,detail}	reaction	0.12	reference	Additional information on reaction
212	{Immunization,reaction,date}	reaction-date	0.12	date	When did reaction start?
213	{Immunization,explanation,reason}	reason	0.12	token	Why immunization occurred
214	{Immunization,explanation,refusalReason}	refusal-reason	0.12	token	Explanation of refusal / exemption
215	{Immunization,refusedIndicator}	refused	0.12	token	Was immunization refused?
216	{Immunization,requester}	requester	0.12	reference	The practitioner who ordered the vaccination
217	{Immunization,subject}	subject	0.12	reference	The subject of the vaccination event / refusal
218	{Immunization,vaccineType}	vaccine-type	0.12	token	Vaccine Product Type Administered
219	{ImmunizationRecommendation}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
220	{ImmunizationRecommendation,recommendation,date}	date	0.12	date	Date recommendation created
221	{ImmunizationRecommendation,recommendation,doseNumber}	dose-number	0.12	number	Recommended dose number
222	{ImmunizationRecommendation,recommendation,protocol,doseSequence}	dose-sequence	0.12	token	Number of dose within sequence
223	{ImmunizationRecommendation,identifier}	identifier	0.12	token	Business identifier
224	{ImmunizationRecommendation,recommendation,supportingPatientInformation}	information	0.12	reference	Patient observations supporting recommendation
225	{ImmunizationRecommendation,recommendation,forecastStatus}	status	0.12	token	Vaccine administration status
226	{ImmunizationRecommendation,subject}	subject	0.12	reference	Who this profile is for
227	{ImmunizationRecommendation,recommendation,supportingImmunization}	support	0.12	reference	Past immunizations supporting recommendation
228	{ImmunizationRecommendation,recommendation,vaccineType}	vaccine-type	0.12	token	Vaccine recommendation applies to
229	{List}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
230	{List,code}	code	0.12	token	What the purpose of this list is
231	{List,date}	date	0.12	date	When the list was prepared
232	{List,emptyReason}	empty-reason	0.12	token	Why list is empty
233	{List,entry,item}	item	0.12	reference	Actual entry
234	{List,source}	source	0.12	reference	Who and/or what defined the list contents
235	{List,subject}	subject	0.12	reference	If all resources have the same subject
236	{Location}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
237	{Location,address}	address	0.12	string	A (part of the) address of the location
238	{Location,identifier}	identifier	0.12	token	Unique code or number identifying the location to its users
239	{Location,name}	name	0.12	string	A (portion of the) name of the location
240	{Location}	near	0.12	token	The coordinates expressed as [lat],[long] (using KML, see notes) to find locations near to (servers may search using a square rather than a circle for efficiency)
241	{Location}	near-distance	0.12	token	A distance quantity to limit the near search to locations within a specific distance
242	{Location,partOf}	partof	0.12	reference	The location of which this location is a part
243	{Location,status}	status	0.12	token	Searches for locations with a specific kind of status
244	{Location,type}	type	0.12	token	A code for the type of location
245	{Media}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
246	{Media,dateTime}	date	0.12	date	When the media was taken/recorded (end)
247	{Media,identifier}	identifier	0.12	token	Identifier(s) for the image
248	{Media,operator}	operator	0.12	reference	The person who generated the image
249	{Media,subject}	subject	0.12	reference	Who/What this Media is a record of
250	{Media,subtype}	subtype	0.12	token	The type of acquisition equipment/process
251	{Media,type}	type	0.12	token	photo | video | audio
252	{Media,view}	view	0.12	token	Imaging view e.g Lateral or Antero-posterior
253	{Medication}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
254	{Medication,code}	code	0.12	token	Codes that identify this medication
255	{Medication,package,container}	container	0.12	token	E.g. box, vial, blister-pack
256	{Medication,package,content,item}	content	0.12	reference	A product in the package
257	{Medication,product,form}	form	0.12	token	powder | tablets | carton +
258	{Medication,product,ingredient,item}	ingredient	0.12	reference	The product contained
259	{Medication,manufacturer}	manufacturer	0.12	reference	Manufacturer of the item
260	{Medication,name}	name	0.12	string	Common / Commercial name
261	{MedicationAdministration}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
262	{MedicationAdministration,device}	device	0.12	reference	Return administrations with this administration device identity
263	{MedicationAdministration,encounter}	encounter	0.12	reference	Return administrations that share this encounter
264	{MedicationAdministration,identifier}	identifier	0.12	token	Return administrations with this external identity
265	{MedicationAdministration,medication}	medication	0.12	reference	Return administrations of this medication
266	{MedicationAdministration,wasNotGiven}	notgiven	0.12	token	Administrations that were not made
267	{MedicationAdministration,patient}	patient	0.12	reference	The identity of a patient to list administrations  for
268	{MedicationAdministration,prescription}	prescription	0.12	reference	The identity of a prescription to list administrations from
269	{MedicationAdministration,status}	status	0.12	token	MedicationAdministration event status (for example one of active/paused/completed/nullified)
270	{MedicationAdministration,whenGiven}	whengiven	0.12	date	Date of administration
271	{MedicationDispense}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
272	{MedicationDispense,dispense,destination}	destination	0.12	reference	Return dispenses that should be sent to a secific destination
273	{MedicationDispense,dispenser}	dispenser	0.12	reference	Return all dispenses performed by a specific indiividual
274	{MedicationDispense,identifier}	identifier	0.12	token	Return dispenses with this external identity
275	{MedicationDispense,dispense,medication}	medication	0.12	reference	Returns dispenses of this medicine
276	{MedicationDispense,patient}	patient	0.12	reference	The identity of a patient to list dispenses  for
277	{MedicationDispense,authorizingPrescription}	prescription	0.12	reference	The identity of a prescription to list dispenses from
278	{MedicationDispense,substitution,responsibleParty}	responsibleparty	0.12	reference	Return all dispenses with the specified responsible party
279	{MedicationDispense,dispense,status}	status	0.12	token	Status of the dispense
280	{MedicationDispense,dispense,type}	type	0.12	token	Return all dispenses of a specific type
281	{MedicationDispense,dispense,whenHandedOver}	whenhandedover	0.12	date	Date when medication handed over to patient (outpatient setting), or supplied to ward or clinic (inpatient setting)
282	{MedicationDispense,dispense,whenPrepared}	whenprepared	0.12	date	Date when medication prepared
283	{MedicationPrescription}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
284	{MedicationPrescription,dateWritten}	datewritten	0.12	date	Return prescriptions written on this date
285	{MedicationPrescription,encounter}	encounter	0.12	reference	Return prescriptions with this encounter identity
286	{MedicationPrescription,identifier}	identifier	0.12	token	Return prescriptions with this external identity
287	{MedicationPrescription,medication}	medication	0.12	reference	Code for medicine or text in medicine name
288	{MedicationPrescription,patient}	patient	0.12	reference	The identity of a patient to list dispenses  for
289	{MedicationPrescription,status}	status	0.12	token	Status of the prescription
290	{MedicationStatement}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
291	{MedicationStatement,device}	device	0.12	reference	Return administrations with this administration device identity
292	{MedicationStatement,identifier}	identifier	0.12	token	Return administrations with this external identity
293	{MedicationStatement,medication}	medication	0.12	reference	Code for medicine or text in medicine name
294	{MedicationStatement,patient}	patient	0.12	reference	The identity of a patient to list administrations  for
295	{MedicationStatement,whenGiven}	when-given	0.12	date	Date of administration
296	{MessageHeader}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
297	{Observation}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
298	{Observation,applies[x]}	date	0.12	date	Obtained date/time. If the obtained element is a period, a date that falls in the period
299	{Observation,name}	name	0.12	token	The name of the observation type
300	{Observation}	name-value-[x]	0.12	composite	Both name and one of the value parameters
301	{Observation,performer}	performer	0.12	reference	Who and/or what performed the observation
302	{Observation}	related	0.12	composite	Related Observations - search on related-type and related-target together
303	{Observation,related,target}	related-target	0.12	reference	Observation that is related to this one
304	{Observation,related,type}	related-type	0.12	token	has-component | has-member | derived-from | sequel-to | replaces | qualified-by | interfered-by
305	{Observation,reliability}	reliability	0.12	token	The reliability of the observation
306	{Observation,specimen}	specimen	0.12	reference	Specimen used for this observation
307	{Observation,status}	status	0.12	token	The status of the observation
308	{Observation,subject}	subject	0.12	reference	The subject that the observation is about
309	{Observation,value[x]}	value-concept	0.12	token	The value of the observation, if the value is a CodeableConcept
310	{Observation,value[x]}	value-date	0.12	date	The value of the observation, if the value is a Period
311	{Observation,value[x]}	value-quantity	0.12	quantity	The value of the observation, if the value is a Quantity, or a SampledData (just search on the bounds of the values in sampled data)
312	{Observation,value[x]}	value-string	0.12	string	The value of the observation, if the value is a string, and also searches in CodeableConcept.text
313	{OperationOutcome}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
314	{Order}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
315	{Order,authority}	authority	0.12	reference	If required by policy
316	{Order,date}	date	0.12	date	When the order was made
317	{Order,detail}	detail	0.12	reference	What action is being ordered
318	{Order,source}	source	0.12	reference	Who initiated the order
319	{Order,subject}	subject	0.12	reference	Patient this order is about
320	{Order,target}	target	0.12	reference	Who is intended to fulfill the order
321	{Order,when,schedule}	when	0.12	date	A formal schedule
322	{Order,when,code}	when_code	0.12	token	Code specifies when request should be done. The code may simply be a priority code
323	{OrderResponse}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
324	{OrderResponse,code}	code	0.12	token	pending | review | rejected | error | accepted | cancelled | replaced | aborted | complete
325	{OrderResponse,date}	date	0.12	date	When the response was made
326	{OrderResponse,fulfillment}	fulfillment	0.12	reference	Details of the outcome of performing the order
327	{OrderResponse,request}	request	0.12	reference	The order that this is a response to
328	{OrderResponse,who}	who	0.12	reference	Who made the response
329	{Organization}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
330	{Organization,active}	active	0.12	token	Whether the organization's record is active
331	{Organization,identifier}	identifier	0.12	token	Any identifier for the organization (not the accreditation issuer's identifier)
332	{Organization,name}	name	0.12	string	A portion of the organization's name
333	{Organization,partOf}	partof	0.12	reference	Search all organizations that are part of the given organization
334	{Organization}	phonetic	0.12	string	A portion of the organization's name using some kind of phonetic matching algorithm
335	{Organization,type}	type	0.12	token	A code for the type of organization
336	{Other}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
337	{Other,code}	code	0.12	token	Kind of Resource
338	{Other,created}	created	0.12	date	When created
339	{Other,subject}	subject	0.12	reference	Identifies the
340	{Patient}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
341	{Patient,active}	active	0.12	token	Whether the patient record is active
342	{Patient,address}	address	0.12	string	An address in any kind of address/part of the patient
343	{Patient,animal,breed}	animal-breed	0.12	token	The breed for animal patients
344	{Patient,animal,species}	animal-species	0.12	token	The species for animal patients
345	{Patient,birthDate}	birthdate	0.12	date	The patient's date of birth
346	{Patient,name,family}	family	0.12	string	A portion of the family name of the patient
347	{Patient,gender}	gender	0.12	token	Gender of the patient
348	{Patient,name,given}	given	0.12	string	A portion of the given name of the patient
349	{Patient,identifier}	identifier	0.12	token	A patient identifier
350	{Patient,communication}	language	0.12	token	Language code (irrespective of use value)
351	{Patient,link,other}	link	0.12	reference	All patients linked to the given patient
352	{Patient,name}	name	0.12	string	A portion of either family or given name of the patient
353	{Patient}	phonetic	0.12	string	A portion of either family or given name using some kind of phonetic matching algorithm
354	{Patient,managingOrganization}	provider	0.12	reference	The organization at which this person is a patient
355	{Patient,telecom}	telecom	0.12	string	The value in any kind of telecom details of the patient
356	{Practitioner}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
357	{Practitioner,address}	address	0.12	string	An address in any kind of address/part
358	{Practitioner,name}	family	0.12	string	A portion of the family name
359	{Practitioner,gender}	gender	0.12	token	Gender of the practitioner
360	{Practitioner,name}	given	0.12	string	A portion of the given name
361	{Practitioner,identifier}	identifier	0.12	token	A practitioner's Identifier
362	{Practitioner,name}	name	0.12	string	A portion of either family or given name
363	{Practitioner,organization}	organization	0.12	reference	The identity of the organization the practitioner represents / acts on behalf of
417	{SecurityEvent}	patientid	0.12	token	The id of the patient (one of multiple kinds of participations)
364	{Practitioner,name}	phonetic	0.12	string	A portion of either family or given name using some kind of phonetic matching algorithm
365	{Practitioner,telecom}	telecom	0.12	string	The value in any kind of contact
366	{Procedure}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
367	{Procedure,date}	date	0.12	date	The date the procedure was performed on
368	{Procedure,subject}	subject	0.12	reference	The identity of a patient to list procedures  for
369	{Procedure,type}	type	0.12	token	Type of procedure
370	{Profile}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
371	{Profile,code}	code	0.12	token	A code for the profile in the format uri::code (server may choose to do subsumption)
372	{Profile,date}	date	0.12	date	The profile publication date
373	{Profile,description}	description	0.12	string	Text search in the description of the profile
374	{Profile,extensionDefn,code}	extension	0.12	token	An extension code (use or definition)
375	{Profile,identifier}	identifier	0.12	token	The identifier of the profile
376	{Profile,name}	name	0.12	string	Name of the profile
377	{Profile,publisher}	publisher	0.12	string	Name of the publisher of the profile
378	{Profile,status}	status	0.12	token	The current status of the profile
379	{Profile,structure,type}	type	0.12	token	Type of resource that is constrained in the profile
380	{Profile,structure,element,definition,binding,reference[x]}	valueset	0.12	reference	A vocabulary binding code
381	{Profile,version}	version	0.12	token	The version identifier of the profile
382	{Provenance}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
383	{Provenance,period,end}	end	0.12	date	End time with inclusive boundary, if not ongoing
384	{Provenance,location}	location	0.12	reference	Where the activity occurred, if relevant
385	{Provenance,agent,reference}	party	0.12	token	Identity of agent (urn or url)
386	{Provenance,agent,type}	partytype	0.12	token	e.g. Resource | Person | Application | Record | Document +
387	{Provenance,period,start}	start	0.12	date	Starting time with inclusive boundary
388	{Provenance,target}	target	0.12	reference	Target resource(s) (usually version specific)
389	{Query}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
390	{Query,identifier}	identifier	0.12	token	Links query and its response(s)
391	{Query,response,identifier}	response	0.12	token	Links response to source query
392	{Questionnaire}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
393	{Questionnaire,author}	author	0.12	reference	The author of the questionnaire
394	{Questionnaire,authored}	authored	0.12	date	When the questionnaire was authored
395	{Questionnaire,encounter}	encounter	0.12	reference	Encounter during which questionnaire was authored
396	{Questionnaire,identifier}	identifier	0.12	token	An identifier for the questionnaire
397	{Questionnaire,name}	name	0.12	token	Name of the questionnaire
398	{Questionnaire,status}	status	0.12	token	The status of the questionnaire
399	{Questionnaire,subject}	subject	0.12	reference	The subject of the questionnaire
400	{RelatedPerson}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
401	{RelatedPerson,address}	address	0.12	string	An address in any kind of address/part
402	{RelatedPerson,gender}	gender	0.12	token	Gender of the person
403	{RelatedPerson,identifier}	identifier	0.12	token	A patient Identifier
404	{RelatedPerson,name}	name	0.12	string	A portion of name in any name part
405	{RelatedPerson,patient}	patient	0.12	reference	The patient this person is related to
406	{RelatedPerson}	phonetic	0.12	string	A portion of name using some kind of phonetic matching algorithm
407	{RelatedPerson,telecom}	telecom	0.12	string	The value in any kind of contact
408	{SecurityEvent}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
409	{SecurityEvent,event,action}	action	0.12	token	Type of action performed during the event
410	{SecurityEvent,participant,network,identifier}	address	0.12	token	Identifier for the network access point of the user device
411	{SecurityEvent,participant,altId}	altid	0.12	token	Alternative User id e.g. authentication
412	{SecurityEvent,event,dateTime}	date	0.12	date	Time when the event occurred on source
413	{SecurityEvent,object,name}	desc	0.12	string	Instance-specific descriptor for Object
414	{SecurityEvent,object,identifier}	identity	0.12	token	Specific instance of object (e.g. versioned)
415	{SecurityEvent,participant,name}	name	0.12	string	Human-meaningful name for the user
416	{SecurityEvent,object,type}	object-type	0.12	token	Object type being audited
418	{SecurityEvent,object,reference}	reference	0.12	reference	Specific instance of resource (e.g. versioned)
419	{SecurityEvent,source,site}	site	0.12	token	Logical source location within the enterprise
420	{SecurityEvent,source,identifier}	source	0.12	token	The id of source where event originated
421	{SecurityEvent,event,subtype}	subtype	0.12	token	More specific type/id for the event
422	{SecurityEvent,event,type}	type	0.12	token	Type/identifier of event
423	{SecurityEvent,participant,userId}	user	0.12	token	Unique identifier for the user
424	{Specimen}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
425	{Specimen,subject}	subject	0.12	reference	The subject of the specimen
426	{Substance}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
427	{Substance,instance,expiry}	expiry	0.12	date	When no longer valid to use
428	{Substance,instance,identifier}	identifier	0.12	token	Identifier of the package/container
429	{Substance,instance,quantity}	quantity	0.12	number	Amount of substance in the package
430	{Substance,ingredient,substance}	substance	0.12	reference	A component of the substance
431	{Substance,type}	type	0.12	token	The type of the substance
432	{Supply}	_id	0.12	token	The logical resource id associated with the resource (must be supported by all servers)
433	{Supply,dispense,identifier}	dispenseid	0.12	token	External identifier
434	{Supply,dispense,status}	dispensestatus	0.12	token	in progress | dispensed | abandoned
435	{Supply,identifier}	identifier	0.12	token	Unique identifier
436	{Supply,kind}	kind	0.12	token	The kind of supply (central, non-stock, etc)
437	{Supply,patient}	patient	0.12	reference	Patient for whom the item is supplied
438	{Supply,status}	status	0.12	token	requested | dispensed | received | failed | cancelled
439	{Supply,dispense,supplier}	supplier	0.12	reference	Dispenser
\.


--
-- Name: resource_search_params__id_seq; Type: SEQUENCE SET; Schema: fhir; Owner: -
--

SELECT pg_catalog.setval('resource_search_params__id_seq', 439, true);


--
-- Data for Name: search_type_to_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY search_type_to_type (stp, tp) FROM stdin;
date	{date,dateTime,instant,Period,Schedule}
token	{boolean,code,CodeableConcept,Coding,Identifier,oid,Resource,string,uri}
number	{integer,decimal,Duration,Quantity}
quantity	{Quantity}
reference	{ResourceReference}
string	{Address,Attachment,CodeableConcept,Contact,HumanName,Period,Quantity,Ratio,Resource,SampledData,string,uri}
\.


SET search_path = public, pg_catalog;

--
-- Data for Name: adversereaction; Type: TABLE DATA; Schema: public; Owner: -
--

COPY adversereaction (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: adversereaction_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY adversereaction_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: alert; Type: TABLE DATA; Schema: public; Owner: -
--

COPY alert (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: alert_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY alert_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: allergyintolerance; Type: TABLE DATA; Schema: public; Owner: -
--

COPY allergyintolerance (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: allergyintolerance_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY allergyintolerance_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: careplan; Type: TABLE DATA; Schema: public; Owner: -
--

COPY careplan (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: careplan_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY careplan_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: composition; Type: TABLE DATA; Schema: public; Owner: -
--

COPY composition (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: composition_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY composition_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: conceptmap; Type: TABLE DATA; Schema: public; Owner: -
--

COPY conceptmap (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: conceptmap_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY conceptmap_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: condition; Type: TABLE DATA; Schema: public; Owner: -
--

COPY condition (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: condition_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY condition_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: conformance; Type: TABLE DATA; Schema: public; Owner: -
--

COPY conformance (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: conformance_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY conformance_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: device; Type: TABLE DATA; Schema: public; Owner: -
--

COPY device (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: device_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY device_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: deviceobservationreport; Type: TABLE DATA; Schema: public; Owner: -
--

COPY deviceobservationreport (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: deviceobservationreport_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY deviceobservationreport_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: diagnosticorder; Type: TABLE DATA; Schema: public; Owner: -
--

COPY diagnosticorder (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: diagnosticorder_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY diagnosticorder_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: diagnosticreport; Type: TABLE DATA; Schema: public; Owner: -
--

COPY diagnosticreport (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: diagnosticreport_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY diagnosticreport_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: documentmanifest; Type: TABLE DATA; Schema: public; Owner: -
--

COPY documentmanifest (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: documentmanifest_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY documentmanifest_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: documentreference; Type: TABLE DATA; Schema: public; Owner: -
--

COPY documentreference (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: documentreference_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY documentreference_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: encounter; Type: TABLE DATA; Schema: public; Owner: -
--

COPY encounter (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: encounter_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY encounter_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: familyhistory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY familyhistory (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: familyhistory_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY familyhistory_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: group; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "group" (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: group_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY group_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: imagingstudy; Type: TABLE DATA; Schema: public; Owner: -
--

COPY imagingstudy (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: imagingstudy_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY imagingstudy_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: immunization; Type: TABLE DATA; Schema: public; Owner: -
--

COPY immunization (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: immunization_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY immunization_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: immunizationrecommendation; Type: TABLE DATA; Schema: public; Owner: -
--

COPY immunizationrecommendation (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: immunizationrecommendation_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY immunizationrecommendation_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: list; Type: TABLE DATA; Schema: public; Owner: -
--

COPY list (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: list_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY list_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: location; Type: TABLE DATA; Schema: public; Owner: -
--

COPY location (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: location_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY location_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: media; Type: TABLE DATA; Schema: public; Owner: -
--

COPY media (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: media_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY media_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medication; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medication (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medication_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medication_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationadministration; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationadministration (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationadministration_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationadministration_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationdispense; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationdispense (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationdispense_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationdispense_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationprescription; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationprescription (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationprescription_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationprescription_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationstatement; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationstatement (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: medicationstatement_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY medicationstatement_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: messageheader; Type: TABLE DATA; Schema: public; Owner: -
--

COPY messageheader (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: messageheader_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY messageheader_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: observation; Type: TABLE DATA; Schema: public; Owner: -
--

COPY observation (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: observation_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY observation_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: operationoutcome; Type: TABLE DATA; Schema: public; Owner: -
--

COPY operationoutcome (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: operationoutcome_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY operationoutcome_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: order; Type: TABLE DATA; Schema: public; Owner: -
--

COPY "order" (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: order_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY order_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: orderresponse; Type: TABLE DATA; Schema: public; Owner: -
--

COPY orderresponse (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: orderresponse_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY orderresponse_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: organization; Type: TABLE DATA; Schema: public; Owner: -
--

COPY organization (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: organization_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY organization_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: other; Type: TABLE DATA; Schema: public; Owner: -
--

COPY other (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: other_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY other_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: patient; Type: TABLE DATA; Schema: public; Owner: -
--

COPY patient (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: patient_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY patient_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: practitioner; Type: TABLE DATA; Schema: public; Owner: -
--

COPY practitioner (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: practitioner_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY practitioner_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: procedure; Type: TABLE DATA; Schema: public; Owner: -
--

COPY procedure (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: procedure_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY procedure_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: profile; Type: TABLE DATA; Schema: public; Owner: -
--

COPY profile (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: profile_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY profile_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: provenance; Type: TABLE DATA; Schema: public; Owner: -
--

COPY provenance (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: provenance_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY provenance_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: query; Type: TABLE DATA; Schema: public; Owner: -
--

COPY query (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: query_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY query_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: questionnaire; Type: TABLE DATA; Schema: public; Owner: -
--

COPY questionnaire (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: questionnaire_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY questionnaire_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: relatedperson; Type: TABLE DATA; Schema: public; Owner: -
--

COPY relatedperson (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: relatedperson_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY relatedperson_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: resource; Type: TABLE DATA; Schema: public; Owner: -
--

COPY resource (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: resource_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY resource_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: securityevent; Type: TABLE DATA; Schema: public; Owner: -
--

COPY securityevent (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: securityevent_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY securityevent_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: specimen; Type: TABLE DATA; Schema: public; Owner: -
--

COPY specimen (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: specimen_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY specimen_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: substance; Type: TABLE DATA; Schema: public; Owner: -
--

COPY substance (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: substance_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY substance_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: supply; Type: TABLE DATA; Schema: public; Owner: -
--

COPY supply (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: supply_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY supply_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: ucum_prefixes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY ucum_prefixes (code, big_code, name, symbol, value, value_text) FROM stdin;
Y	YA	yotta	Y	1000000000000000000000000	1 × 10
Z	ZA	zetta	Z	1000000000000000000000	1 × 10
E	EX	exa	E	1000000000000000000	1 × 10
P	PT	peta	P	1000000000000000	1 × 10
T	TR	tera	T	1000000000000	1 × 10
G	GA	giga	G	1000000000	1 × 10
M	MA	mega	M	1000000	1 × 10
k	K	kilo	k	1000	1 × 10
h	H	hecto	h	100	1 × 10
da	DA	deka	da	10	1 × 10
d	D	deci	d	0.1	1 × 10
c	C	centi	c	0.01	1 × 10
m	M	milli	m	0.001	1 × 10
u	U	micro	μ	0.000001	1 × 10
n	N	nano	n	0.000000001	1 × 10
p	P	pico	p	0.000000000001	1 × 10
f	F	femto	f	0.000000000000001	1 × 10
a	A	atto	a	0.000000000000000001	1 × 10
z	ZO	zepto	z	0.000000000000000000001	1 × 10
y	YO	yocto	y	0.000000000000000000000001	1 × 10
Ki	KIB	kibi	Ki	1024	1024
Mi	MIB	mebi	Mi	1048576	1048576
Gi	GIB	gibi	Gi	1073741824	1073741824
Ti	TIB	tebi	Ti	1099511627776	1099511627776
\.


--
-- Data for Name: ucum_units; Type: TABLE DATA; Schema: public; Owner: -
--

COPY ucum_units (code, is_metric, class, name, symbol, property, unit, value, value_text, func_name, func_value, func_unit) FROM stdin;
10*	no	dimless	the number ten for arbitrary powers	10	number	1	10	10	\N	\N	\N
10^	no	dimless	the number ten for arbitrary powers	10	number	1	10	10	\N	\N	\N
[pi]	no	dimless	the number pi	π	number	1	3.1415926535897932384626433832795028841971693993751058209749445923	π	\N	\N	\N
%	no	dimless	percent	%	fraction	10*-2	1	1	\N	\N	\N
[ppth]	no	dimless	parts per thousand	ppth	fraction	10*-3	1	1	\N	\N	\N
[ppm]	no	dimless	parts per million	ppm	fraction	10*-6	1	1	\N	\N	\N
[ppb]	no	dimless	parts per billion	ppb	fraction	10*-9	1	1	\N	\N	\N
[pptr]	no	dimless	parts per trillion	pptr	fraction	10*-12	1	1	\N	\N	\N
mol	yes	si	mole	mol	amount of substance	10*23	6.0221367	6.0221367	\N	\N	\N
sr	yes	si	steradian	sr	solid angle	rad2	1	1	\N	\N	\N
Hz	yes	si	Hertz	Hz	frequency	s-1	1	1	\N	\N	\N
N	yes	si	Newton	N	force	kg.m/s2	1	1	\N	\N	\N
Pa	yes	si	Pascal	Pa	pressure	N/m2	1	1	\N	\N	\N
J	yes	si	Joule	J	energy	N.m	1	1	\N	\N	\N
W	yes	si	Watt	W	power	J/s	1	1	\N	\N	\N
A	yes	si	Ampère	A	electric current	C/s	1	1	\N	\N	\N
V	yes	si	Volt	V	electric potential	J/C	1	1	\N	\N	\N
F	yes	si	Farad	F	electric capacitance	C/V	1	1	\N	\N	\N
Ohm	yes	si	Ohm	Ω	electric resistance	V/A	1	1	\N	\N	\N
S	yes	si	Siemens	S	electric conductance	Ohm-1	1	1	\N	\N	\N
Wb	yes	si	Weber	Wb	magentic flux	V.s	1	1	\N	\N	\N
Cel	yes	si	degree Celsius	°C	temperature	cel(1 K)	\N	\n         	Cel	1	K
T	yes	si	Tesla	T	magnetic flux density	Wb/m2	1	1	\N	\N	\N
H	yes	si	Henry	H	inductance	Wb/A	1	1	\N	\N	\N
lm	yes	si	lumen	lm	luminous flux	cd.sr	1	1	\N	\N	\N
lx	yes	si	lux	lx	illuminance	lm/m2	1	1	\N	\N	\N
Bq	yes	si	Becquerel	Bq	radioactivity	s-1	1	1	\N	\N	\N
Gy	yes	si	Gray	Gy	energy dose	J/kg	1	1	\N	\N	\N
Sv	yes	si	Sievert	Sv	dose equivalent	J/kg	1	1	\N	\N	\N
gon	no	iso1000	gon	□	plane angle	deg	0.9	0.9	\N	\N	\N
deg	no	iso1000	degree	°	plane angle	[pi].rad/360	2	2	\N	\N	\N
'	no	iso1000	minute	'	plane angle	deg/60	1	1	\N	\N	\N
''	no	iso1000	second	''	plane angle	'/60	1	1	\N	\N	\N
l	yes	iso1000	liter	l	volume	dm3	1	1	\N	\N	\N
L	yes	iso1000	liter	L	volume	l	1	1	\N	\N	\N
ar	yes	iso1000	are	a	area	m2	100	100	\N	\N	\N
min	no	iso1000	minute	min	time	s	60	60	\N	\N	\N
h	no	iso1000	hour	h	time	min	60	60	\N	\N	\N
d	no	iso1000	day	d	time	h	24	24	\N	\N	\N
a_t	no	iso1000	tropical year	a	time	d	365.24219	365.24219	\N	\N	\N
a_j	no	iso1000	mean Julian year	a	time	d	365.25	365.25	\N	\N	\N
a_g	no	iso1000	mean Gregorian year	a	time	d	365.2425	365.2425	\N	\N	\N
a	no	iso1000	year	a	time	a_j	1	1	\N	\N	\N
wk	no	iso1000	week	wk	time	d	7	7	\N	\N	\N
mo_s	no	iso1000	synodal month	mo	time	d	29.53059	29.53059	\N	\N	\N
mo_j	no	iso1000	mean Julian month	mo	time	a_j/12	1	1	\N	\N	\N
mo_g	no	iso1000	mean Gregorian month	mo	time	a_g/12	1	1	\N	\N	\N
mo	no	iso1000	month	mo	time	mo_j	1	1	\N	\N	\N
t	yes	iso1000	tonne	t	mass	kg	1e3	1 × 10	\N	\N	\N
bar	yes	iso1000	bar	bar	pressure	Pa	1e5	1 × 10	\N	\N	\N
u	yes	iso1000	unified atomic mass unit	u	mass	g	1.6605402e-24	1.6605402 × 10	\N	\N	\N
eV	yes	iso1000	electronvolt	eV	energy	[e].V	1	1	\N	\N	\N
AU	no	iso1000	astronomic unit	AU	length	Mm	149597.870691	149597.870691	\N	\N	\N
pc	yes	iso1000	parsec	pc	length	m	3.085678e16	3.085678 × 10	\N	\N	\N
[c]	yes	const	velocity of light	\n         	velocity	m/s	299792458	299792458	\N	\N	\N
[h]	yes	const	Planck constant	\n         	action	J.s	6.6260755e-24	6.6260755 × 10	\N	\N	\N
[k]	yes	const	Boltzmann constant	\n         	(unclassified)	J/K	1.380658e-23	1.380658 × 10	\N	\N	\N
[eps_0]	yes	const	permittivity of vacuum	\n         	electric permittivity	F/m	8.854187817e-12	8.854187817 × 10	\N	\N	\N
[mu_0]	yes	const	permeability of vacuum	\n         	magnetic permeability	4.[pi].10*-7.N/A2	1	1	\N	\N	\N
[e]	yes	const	elementary charge	\n         	electric charge	C	1.60217733e-19	1.60217733 × 10	\N	\N	\N
[m_e]	yes	const	electron mass	\n         	mass	g	9.1093897e-28	9.1093897 × 10	\N	\N	\N
[m_p]	yes	const	proton mass	\n         	mass	g	1.6726231e-24	1.6726231 × 10	\N	\N	\N
[G]	yes	const	Newtonian constant of gravitation	\n         	(unclassified)	m3.kg-1.s-2	6.67259e-11	6.67259 × 10	\N	\N	\N
[g]	yes	const	standard acceleration of free fall	\n         	acceleration	m/s2	980665e-5	9.80665	\N	\N	\N
atm	no	const	standard atmosphere	atm	pressure	Pa	101325	101325	\N	\N	\N
[ly]	yes	const	light-year	l.y.	length	[c].a_j	1	1	\N	\N	\N
gf	yes	const	gram-force	gf	force	g.[g]	1	1	\N	\N	\N
[lbf_av]	no	const	pound force	lbf	force	[lb_av].[g]	1	1	\N	\N	\N
Ky	yes	cgs	Kayser	K	lineic number	cm-1	1	1	\N	\N	\N
Gal	yes	cgs	Gal	Gal	acceleration	cm/s2	1	1	\N	\N	\N
dyn	yes	cgs	dyne	dyn	force	g.cm/s2	1	1	\N	\N	\N
erg	yes	cgs	erg	erg	energy	dyn.cm	1	1	\N	\N	\N
P	yes	cgs	Poise	P	dynamic viscosity	dyn.s/cm2	1	1	\N	\N	\N
Bi	yes	cgs	Biot	Bi	electric current	A	10	10	\N	\N	\N
St	yes	cgs	Stokes	St	kinematic viscosity	cm2/s	1	1	\N	\N	\N
Mx	yes	cgs	Maxwell	Mx	flux of magnetic induction	Wb	1e-8	1 × 10	\N	\N	\N
G	yes	cgs	Gauss	Gs	magnetic flux density	T	1e-4	1 × 10	\N	\N	\N
Oe	yes	cgs	Oersted	Oe	magnetic field intensity	/[pi].A/m	250	250	\N	\N	\N
Gb	yes	cgs	Gilbert	Gb	magnetic tension	Oe.cm	1	1	\N	\N	\N
sb	yes	cgs	stilb	sb	lum. intensity density	cd/cm2	1	1	\N	\N	\N
Lmb	yes	cgs	Lambert	L	brightness	cd/cm2/[pi]	1	1	\N	\N	\N
ph	yes	cgs	phot	ph	illuminance	lx	1e-4	1 × 10	\N	\N	\N
Ci	yes	cgs	Curie	Ci	radioactivity	Bq	37e9	3.7 × 10	\N	\N	\N
R	yes	cgs	Roentgen	R	ion dose	C/kg	2.58e-4	2.58 × 10	\N	\N	\N
RAD	yes	cgs	radiation absorbed dose	RAD	energy dose	erg/g	100	100	\N	\N	\N
REM	yes	cgs	radiation equivalent man	REM	dose equivalent	RAD	1	1	\N	\N	\N
[in_i]	no	intcust	inch	in	length	cm	254e-2	2.54	\N	\N	\N
[ft_i]	no	intcust	foot	ft	length	[in_i]	12	12	\N	\N	\N
[yd_i]	no	intcust	yard	yd	length	[ft_i]	3	3	\N	\N	\N
[mi_i]	no	intcust	statute mile	mi	length	[ft_i]	5280	5280	\N	\N	\N
[fth_i]	no	intcust	fathom	fth	depth of water	[ft_i]	6	6	\N	\N	\N
[nmi_i]	no	intcust	nautical mile	n.mi	length	m	1852	1852	\N	\N	\N
[kn_i]	no	intcust	knot	knot	velocity	[nmi_i]/h	1	1	\N	\N	\N
[sin_i]	no	intcust	square inch	\N	area	[in_i]2	1	1	\N	\N	\N
[sft_i]	no	intcust	square foot	\N	area	[ft_i]2	1	1	\N	\N	\N
[syd_i]	no	intcust	square yard	\N	area	[yd_i]2	1	1	\N	\N	\N
[cin_i]	no	intcust	cubic inch	\N	volume	[in_i]3	1	1	\N	\N	\N
[cft_i]	no	intcust	cubic foot	\N	volume	[ft_i]3	1	1	\N	\N	\N
[cyd_i]	no	intcust	cubic yard	cu.yd	volume	[yd_i]3	1	1	\N	\N	\N
[bf_i]	no	intcust	board foot	\N	volume	[in_i]3	144	144	\N	\N	\N
[cr_i]	no	intcust	cord	\N	volume	[ft_i]3	128	128	\N	\N	\N
[mil_i]	no	intcust	mil	mil	length	[in_i]	1e-3	1 × 10	\N	\N	\N
[cml_i]	no	intcust	circular mil	circ.mil	area	[pi]/4.[mil_i]2	1	1	\N	\N	\N
[hd_i]	no	intcust	hand	hd	height of horses	[in_i]	4	4	\N	\N	\N
[ft_us]	no	us-lengths	foot	ft	length	m/3937	1200	1200	\N	\N	\N
[yd_us]	no	us-lengths	yard	\N	length	[ft_us]	3	3	\N	\N	\N
[in_us]	no	us-lengths	inch	\N	length	[ft_us]/12	1	1	\N	\N	\N
[rd_us]	no	us-lengths	rod	\N	length	[ft_us]	16.5	16.5	\N	\N	\N
[ch_us]	no	us-lengths	Gunter's chain	\N	length	[rd_us]	4	4	\N	\N	\N
[lk_us]	no	us-lengths	link for Gunter's chain	\N	length	[ch_us]/100	1	1	\N	\N	\N
[rch_us]	no	us-lengths	Ramden's chain	\N	length	[ft_us]	100	100	\N	\N	\N
[rlk_us]	no	us-lengths	link for Ramden's chain	\N	length	[rch_us]/100	1	1	\N	\N	\N
[fth_us]	no	us-lengths	fathom	\N	length	[ft_us]	6	6	\N	\N	\N
[fur_us]	no	us-lengths	furlong	\N	length	[rd_us]	40	40	\N	\N	\N
[mi_us]	no	us-lengths	mile	\N	length	[fur_us]	8	8	\N	\N	\N
[acr_us]	no	us-lengths	acre	\N	area	[rd_us]2	160	160	\N	\N	\N
[srd_us]	no	us-lengths	square rod	\N	area	[rd_us]2	1	1	\N	\N	\N
[smi_us]	no	us-lengths	square mile	\N	area	[mi_us]2	1	1	\N	\N	\N
[sct]	no	us-lengths	section	\N	area	[mi_us]2	1	1	\N	\N	\N
[twp]	no	us-lengths	township	\N	area	[sct]	36	36	\N	\N	\N
[mil_us]	no	us-lengths	mil	\N	length	[in_us]	1e-3	1 × 10	\N	\N	\N
[in_br]	no	brit-length	inch	\N	length	cm	2.539998	2.539998	\N	\N	\N
[ft_br]	no	brit-length	foot	\N	length	[in_br]	12	12	\N	\N	\N
[rd_br]	no	brit-length	rod	\N	length	[ft_br]	16.5	16.5	\N	\N	\N
[ch_br]	no	brit-length	Gunter's chain	\N	length	[rd_br]	4	4	\N	\N	\N
[lk_br]	no	brit-length	link for Gunter's chain	\N	length	[ch_br]/100	1	1	\N	\N	\N
[fth_br]	no	brit-length	fathom	\N	length	[ft_br]	6	6	\N	\N	\N
[pc_br]	no	brit-length	pace	\N	length	[ft_br]	2.5	2.5	\N	\N	\N
[yd_br]	no	brit-length	yard	\N	length	[ft_br]	3	3	\N	\N	\N
[mi_br]	no	brit-length	mile	\N	length	[ft_br]	5280	5280	\N	\N	\N
[nmi_br]	no	brit-length	nautical mile	\N	length	[ft_br]	6080	6080	\N	\N	\N
[kn_br]	no	brit-length	knot	\N	velocity	[nmi_br]/h	1	1	\N	\N	\N
[acr_br]	no	brit-length	acre	\N	area	[yd_br]2	4840	4840	\N	\N	\N
[gal_us]	no	us-volumes	Queen Anne's wine gallon	\N	fluid volume	[in_i]3	231	231	\N	\N	\N
[bbl_us]	no	us-volumes	barrel	\N	fluid volume	[gal_us]	42	42	\N	\N	\N
[qt_us]	no	us-volumes	quart	\N	fluid volume	[gal_us]/4	1	1	\N	\N	\N
[pt_us]	no	us-volumes	pint	\N	fluid volume	[qt_us]/2	1	1	\N	\N	\N
[gil_us]	no	us-volumes	gill	\N	fluid volume	[pt_us]/4	1	1	\N	\N	\N
[foz_us]	no	us-volumes	fluid ounce	oz fl	fluid volume	[gil_us]/4	1	1	\N	\N	\N
[fdr_us]	no	us-volumes	fluid dram	\N	fluid volume	[foz_us]/8	1	1	\N	\N	\N
[min_us]	no	us-volumes	minim	\N	fluid volume	[fdr_us]/60	1	1	\N	\N	\N
[crd_us]	no	us-volumes	cord	\N	fluid volume	[ft_i]3	128	128	\N	\N	\N
[bu_us]	no	us-volumes	bushel	\N	dry volume	[in_i]3	2150.42	2150.42	\N	\N	\N
[gal_wi]	no	us-volumes	historical winchester gallon	\N	dry volume	[bu_us]/8	1	1	\N	\N	\N
[pk_us]	no	us-volumes	peck	\N	dry volume	[bu_us]/4	1	1	\N	\N	\N
[dqt_us]	no	us-volumes	dry quart	\N	dry volume	[pk_us]/8	1	1	\N	\N	\N
[dpt_us]	no	us-volumes	dry pint	\N	dry volume	[dqt_us]/2	1	1	\N	\N	\N
[tbs_us]	no	us-volumes	tablespoon	\N	volume	[foz_us]/2	1	1	\N	\N	\N
[tsp_us]	no	us-volumes	teaspoon	\N	volume	[tbs_us]/3	1	1	\N	\N	\N
[cup_us]	no	us-volumes	cup	\N	volume	[tbs_us]	16	16	\N	\N	\N
[foz_m]	no	us-volumes	metric fluid ounce	oz fl	fluid volume	mL	30	30	\N	\N	\N
[cup_m]	no	us-volumes	metric cup	\N	volume	mL	240	240	\N	\N	\N
[tsp_m]	no	us-volumes	metric teaspoon	\N	volume	mL	5	5	\N	\N	\N
[tbs_m]	no	us-volumes	metric tablespoon	\N	volume	mL	15	15	\N	\N	\N
[gal_br]	no	brit-volumes	gallon	\N	volume	l	4.54609	4.54609	\N	\N	\N
[pk_br]	no	brit-volumes	peck	\N	volume	[gal_br]	2	2	\N	\N	\N
[bu_br]	no	brit-volumes	bushel	\N	volume	[pk_br]	4	4	\N	\N	\N
[qt_br]	no	brit-volumes	quart	\N	volume	[gal_br]/4	1	1	\N	\N	\N
[pt_br]	no	brit-volumes	pint	\N	volume	[qt_br]/2	1	1	\N	\N	\N
[gil_br]	no	brit-volumes	gill	\N	volume	[pt_br]/4	1	1	\N	\N	\N
[foz_br]	no	brit-volumes	fluid ounce	\N	volume	[gil_br]/5	1	1	\N	\N	\N
[fdr_br]	no	brit-volumes	fluid dram	\N	volume	[foz_br]/8	1	1	\N	\N	\N
[min_br]	no	brit-volumes	minim	\N	volume	[fdr_br]/60	1	1	\N	\N	\N
[gr]	no	avoirdupois	grain	\N	mass	mg	64.79891	64.79891	\N	\N	\N
[lb_av]	no	avoirdupois	pound	lb	mass	[gr]	7000	7000	\N	\N	\N
[oz_av]	no	avoirdupois	ounce	oz	mass	[lb_av]/16	1	1	\N	\N	\N
[dr_av]	no	avoirdupois	dram	\N	mass	[oz_av]/16	1	1	\N	\N	\N
[scwt_av]	no	avoirdupois	short hundredweight	\N	mass	[lb_av]	100	100	\N	\N	\N
[lcwt_av]	no	avoirdupois	long hunderdweight	\N	mass	[lb_av]	112	112	\N	\N	\N
[ston_av]	no	avoirdupois	short ton	\N	mass	[scwt_av]	20	20	\N	\N	\N
[lton_av]	no	avoirdupois	long ton	\N	mass	[lcwt_av]	20	20	\N	\N	\N
[stone_av]	no	avoirdupois	stone	\N	mass	[lb_av]	14	14	\N	\N	\N
[pwt_tr]	no	troy	pennyweight	\N	mass	[gr]	24	24	\N	\N	\N
[oz_tr]	no	troy	ounce	\N	mass	[pwt_tr]	20	20	\N	\N	\N
[lb_tr]	no	troy	pound	\N	mass	[oz_tr]	12	12	\N	\N	\N
[sc_ap]	no	apoth	scruple	\N	mass	[gr]	20	20	\N	\N	\N
[dr_ap]	no	apoth	dram	\N	mass	[sc_ap]	3	3	\N	\N	\N
[oz_ap]	no	apoth	ounce	\N	mass	[dr_ap]	8	8	\N	\N	\N
[lb_ap]	no	apoth	pound	\N	mass	[oz_ap]	12	12	\N	\N	\N
[oz_m]	no	apoth	metric ounce	\N	mass	g	28	28	\N	\N	\N
[lne]	no	typeset	line	\N	length	[in_i]/12	1	1	\N	\N	\N
[pnt]	no	typeset	point	\N	length	[lne]/6	1	1	\N	\N	\N
[pca]	no	typeset	pica	\N	length	[pnt]	12	12	\N	\N	\N
[pnt_pr]	no	typeset	Printer's point	\N	length	[in_i]	0.013837	0.013837	\N	\N	\N
[pca_pr]	no	typeset	Printer's pica	\N	length	[pnt_pr]	12	12	\N	\N	\N
[pied]	no	typeset	pied	\N	length	cm	32.48	32.48	\N	\N	\N
[pouce]	no	typeset	pouce	\N	length	[pied]/12	1	1	\N	\N	\N
[ligne]	no	typeset	ligne	\N	length	[pouce]/12	1	1	\N	\N	\N
[didot]	no	typeset	didot	\N	length	[ligne]/6	1	1	\N	\N	\N
[cicero]	no	typeset	cicero	\N	length	[didot]	12	12	\N	\N	\N
[degF]	no	heat	degree Fahrenheit	°F	temperature	degf(5 K/9)	\N	\n         	degF	5	K/9
[degR]	no	heat	degree Rankine	°R	temperature	K/9	5	5	\N	\N	\N
cal_[15]	yes	heat	calorie at 15 °C	cal	energy	J	4.18580	4.18580	\N	\N	\N
cal_[20]	yes	heat	calorie at 20 °C	cal	energy	J	4.18190	4.18190	\N	\N	\N
cal_m	yes	heat	mean calorie	cal	energy	J	4.19002	4.19002	\N	\N	\N
cal_IT	yes	heat	international table calorie	cal	energy	J	4.1868	4.1868	\N	\N	\N
cal_th	yes	heat	thermochemical calorie	cal	energy	J	4.184	4.184	\N	\N	\N
cal	yes	heat	calorie	cal	energy	cal_th	1	1	\N	\N	\N
[Cal]	no	heat	nutrition label Calories	Cal	energy	kcal_th	1	1	\N	\N	\N
[Btu_39]	no	heat	British thermal unit at 39 °F	Btu	energy	kJ	1.05967	1.05967	\N	\N	\N
[Btu_59]	no	heat	British thermal unit at 59 °F	Btu	energy	kJ	1.05480	1.05480	\N	\N	\N
[Btu_60]	no	heat	British thermal unit at 60 °F	Btu	energy	kJ	1.05468	1.05468	\N	\N	\N
[Btu_m]	no	heat	mean British thermal unit	Btu	energy	kJ	1.05587	1.05587	\N	\N	\N
[Btu_IT]	no	heat	international table British thermal unit	Btu	energy	kJ	1.05505585262	1.05505585262	\N	\N	\N
[Btu_th]	no	heat	thermochemical British thermal unit	Btu	energy	kJ	1.054350	1.054350	\N	\N	\N
[Btu]	no	heat	British thermal unit	btu	energy	[Btu_th]	1	1	\N	\N	\N
[HP]	no	heat	horsepower	\N	power	[ft_i].[lbf_av]/s	550	550	\N	\N	\N
tex	yes	heat	tex	tex	linear mass density (of textile thread)	g/km	1	1	\N	\N	\N
[den]	no	heat	Denier	den	linear mass density (of textile thread)	g/9/km	1	1	\N	\N	\N
m[H2O]	yes	clinical	meter of water column	m H	pressure	kPa	980665e-5	9.80665	\N	\N	\N
m[Hg]	yes	clinical	meter of mercury column	m Hg	pressure	kPa	133.3220	133.3220	\N	\N	\N
[in_i'H2O]	no	clinical	inch of water column	in H	pressure	m[H2O].[in_i]/m	1	1	\N	\N	\N
[in_i'Hg]	no	clinical	inch of mercury column	in Hg	pressure	m[Hg].[in_i]/m	1	1	\N	\N	\N
[PRU]	no	clinical	peripheral vascular resistance unit	P.R.U.	fluid resistance	mm[Hg].s/ml	1	1	\N	\N	\N
[wood'U]	no	clinical	Wood unit	Wood U.	fluid resistance	mm[Hg].min/L	1	1	\N	\N	\N
[diop]	no	clinical	diopter	dpt	refraction of a lens	/m	1	1	\N	\N	\N
[p'diop]	no	clinical	prism diopter	PD	refraction of a prism	100tan(1 rad)	\N	\n         	tanTimes100	1	deg
%[slope]	no	clinical	percent of slope	%	slope	100tan(1 rad)	\N	\n         	100tan	1	deg
[mesh_i]	no	clinical	mesh	\N	lineic number	/[in_i]	1	1	\N	\N	\N
[Ch]	no	clinical	Charrière	Ch	gauge of catheters	mm/3	1	1	\N	\N	\N
[drp]	no	clinical	drop	drp	volume	ml/20	1	1	\N	\N	\N
[hnsf'U]	no	clinical	Hounsfield unit	HF	x-ray attenuation	1	1	1	\N	\N	\N
[MET]	no	clinical	metabolic equivalent	MET	metabolic cost of physical activity	mL/min/kg	3.5	3.5	\N	\N	\N
[hp'_X]	no	clinical	homeopathic potency of decimal series (retired)	X	homeopathic potency (retired)	hpX(1 1)	\N	\n         	hpX	1	1
[hp'_C]	no	clinical	homeopathic potency of centesimal series (retired)	C	homeopathic potency (retired)	hpC(1 1)	\N	\n         	hpC	1	1
[hp'_M]	no	clinical	homeopathic potency of millesimal series (retired)	M	homeopathic potency (retired)	hpM(1 1)	\N	\n         	hpM	1	1
[hp'_Q]	no	clinical	homeopathic potency of quintamillesimal series (retired)	Q	homeopathic potency (retired)	hpQ(1 1)	\N	\n         	hpQ	1	1
[hp_X]	no	clinical	homeopathic potency of decimal hahnemannian series	X	homeopathic potency (Hahnemann)	1	1	1	\N	\N	\N
[hp_C]	no	clinical	homeopathic potency of centesimal hahnemannian series	C	homeopathic potency (Hahnemann)	1	1	1	\N	\N	\N
[hp_M]	no	clinical	homeopathic potency of millesimal hahnemannian series	M	homeopathic potency (Hahnemann)	1	1	1	\N	\N	\N
[hp_Q]	no	clinical	homeopathic potency of quintamillesimal hahnemannian series	Q	homeopathic potency (Hahnemann)	1	1	1	\N	\N	\N
[kp_X]	no	clinical	homeopathic potency of decimal korsakovian series	X	homeopathic potency (Korsakov)	1	1	1	\N	\N	\N
[kp_C]	no	clinical	homeopathic potency of centesimal korsakovian series	C	homeopathic potency (Korsakov)	1	1	1	\N	\N	\N
[kp_M]	no	clinical	homeopathic potency of millesimal korsakovian series	M	homeopathic potency (Korsakov)	1	1	1	\N	\N	\N
[kp_Q]	no	clinical	homeopathic potency of quintamillesimal korsakovian series	Q	homeopathic potency (Korsakov)	1	1	1	\N	\N	\N
eq	yes	chemical	equivalents	eq	amount of substance	mol	1	1	\N	\N	\N
osm	yes	chemical	osmole	osm	amount of substance (dissolved particles)	mol	1	1	\N	\N	\N
[pH]	no	chemical	pH	pH	acidity	pH(1 mol/l)	\N	\n         	pH	1	mol/l
g%	yes	chemical	gram percent	g%	mass concentration	g/dl	1	1	\N	\N	\N
[S]	no	chemical	Svedberg unit	S	sedimentation coefficient	10*-13.s	1	1	\N	\N	\N
[HPF]	no	chemical	high power field	HPF	view area in microscope	1	1	1	\N	\N	\N
[LPF]	no	chemical	low power field	LPF	view area in microscope	1	100	100	\N	\N	\N
kat	yes	chemical	katal	kat	catalytic activity	mol/s	1	1	\N	\N	\N
U	yes	chemical	Unit	U	catalytic activity	umol/min	1	1	\N	\N	\N
[iU]	yes	chemical	international unit	IU	arbitrary	1	1	1	\N	\N	\N
[IU]	yes	chemical	international unit	i.U.	arbitrary	[iU]	1	1	\N	\N	\N
[arb'U]	no	chemical	arbitary unit	arb. U	arbitrary	1	1	1	\N	\N	\N
[USP'U]	no	chemical	United States Pharmacopeia unit	U.S.P.	arbitrary	1	1	1	\N	\N	\N
[GPL'U]	no	chemical	GPL unit	\N	biologic activity of anticardiolipin IgG	1	1	1	\N	\N	\N
[MPL'U]	no	chemical	MPL unit	\N	biologic activity of anticardiolipin IgM	1	1	1	\N	\N	\N
[APL'U]	no	chemical	APL unit	\N	biologic activity of anticardiolipin IgA	1	1	1	\N	\N	\N
[beth'U]	no	chemical	Bethesda unit	\N	biologic activity of factor VIII inhibitor	1	1	1	\N	\N	\N
[anti'Xa'U]	no	chemical	anti factor Xa unit	\N	biologic activity of factor Xa inhibitor (heparin)	1	1	1	\N	\N	\N
[todd'U]	no	chemical	Todd unit	\N	biologic activity antistreptolysin O	1	1	1	\N	\N	\N
[dye'U]	no	chemical	Dye unit	\N	biologic activity of amylase	1	1	1	\N	\N	\N
[smgy'U]	no	chemical	Somogyi unit	\N	biologic activity of amylase	1	1	1	\N	\N	\N
[bdsk'U]	no	chemical	Bodansky unit	\N	biologic activity of phosphatase	1	1	1	\N	\N	\N
[ka'U]	no	chemical	King-Armstrong unit	\N	biologic activity of phosphatase	1	1	1	\N	\N	\N
[knk'U]	no	chemical	Kunkel unit	\N	arbitrary biologic activity	1	1	1	\N	\N	\N
[mclg'U]	no	chemical	Mac Lagan unit	\N	arbitrary biologic activity	1	1	1	\N	\N	\N
[tb'U]	no	chemical	tuberculin unit	\N	biologic activity of tuberculin	1	1	1	\N	\N	\N
[CCID_50]	no	chemical	50% cell culture infectious dose	CCID	biologic activity (infectivity) of an infectious agent preparation	1	1	1	\N	\N	\N
[TCID_50]	no	chemical	50% tissue culture infectious dose	TCID	biologic activity (infectivity) of an infectious agent preparation	1	1	1	\N	\N	\N
[EID_50]	no	chemical	50% embryo infectious dose	EID	biologic activity (infectivity) of an infectious agent preparation	1	1	1	\N	\N	\N
[PFU]	no	chemical	plaque forming units	PFU	amount of an infectious agent	1	1	1	\N	\N	\N
[FFU]	no	chemical	focus forming units	FFU	amount of an infectious agent	1	1	1	\N	\N	\N
[CFU]	no	chemical	colony forming units	CFU	amount of a proliferating organism	1	1	1	\N	\N	\N
[BAU]	no	chemical	bioequivalent allergen unit	BAU	amount of an allergen callibrated through in-vivo testing based on the ID50EAL method of (intradermal dilution for 50mm sum of erythema diameters	1	1	1	\N	\N	\N
[AU]	no	chemical	allergen unit	AU	procedure defined amount of an allergen using some reference standard	1	1	1	\N	\N	\N
[Amb'a'1'U]	no	chemical	allergen unit for Ambrosia artemisiifolia	Amb a 1 U	procedure defined amount of the major allergen of ragweed.	1	1	1	\N	\N	\N
[PNU]	no	chemical	protein nitrogen unit	PNU	procedure defined amount of a protein substance	1	1	1	\N	\N	\N
[Lf]	no	chemical	Limit of flocculation	Lf	procedure defined amount of an antigen substance	1	1	1	\N	\N	\N
[D'ag'U]	no	chemical	D-antigen unit	\N	procedure defined amount of a poliomyelitis d-antigen substance	1	1	1	\N	\N	\N
[FEU]	no	chemical	fibrinogen equivalent unit	\N	amount of fibrinogen broken down into the measured d-dimers	1	1	1	\N	\N	\N
[ELU]	no	chemical	ELISA unit	\N	arbitrary ELISA unit	1	1	1	\N	\N	\N
[EU]	no	chemical	Ehrlich unit	\N	Ehrlich unit	1	1	1	\N	\N	\N
Np	yes	levels	neper	Np	level	ln(1 1)	\N	\n         	ln	1	1
B	yes	levels	bel	B	level	lg(1 1)	\N	\n         	lg	1	1
B[SPL]	yes	levels	bel sound pressure	B(SPL)	pressure level	2lg(2 10*-5.Pa)	\N	\n         	lgTimes2	2	10*-5.Pa
B[V]	yes	levels	bel volt	B(V)	electric potential level	2lg(1 V)	\N	\n         	lgTimes2	1	V
B[mV]	yes	levels	bel millivolt	B(mV)	electric potential level	2lg(1 mV)	\N	\n         	lgTimes2	1	mV
B[uV]	yes	levels	bel microvolt	B(μV)	electric potential level	2lg(1 uV)	\N	\n         	lgTimes2	1	uV
B[10.nV]	yes	levels	bel 10 nanovolt	B(10 nV)	electric potential level	2lg(10 nV)	\N	\n         	lgTimes2	10	nV
B[W]	yes	levels	bel watt	B(W)	power level	lg(1 W)	\N	\n         	lg	1	W
B[kW]	yes	levels	bel kilowatt	B(kW)	power level	lg(1 kW)	\N	\n         	lg	1	kW
st	yes	misc	stere	st	volume	m3	1	1	\N	\N	\N
Ao	no	misc	Ångström	Å	length	nm	0.1	0.1	\N	\N	\N
b	no	misc	barn	b	action area	fm2	100	100	\N	\N	\N
att	no	misc	technical atmosphere	at	pressure	kgf/cm2	1	1	\N	\N	\N
mho	yes	misc	mho	mho	electric conductance	S	1	1	\N	\N	\N
[psi]	no	misc	pound per sqare inch	psi	pressure	[lbf_av]/[in_i]2	1	1	\N	\N	\N
circ	no	misc	circle	circ	plane angle	[pi].rad	2	2	\N	\N	\N
sph	no	misc	spere	sph	solid angle	[pi].sr	4	4	\N	\N	\N
[car_m]	no	misc	metric carat	ct	mass	g	2e-1	0.2	\N	\N	\N
[car_Au]	no	misc	carat of gold alloys	ct	mass fraction	/24	1	1	\N	\N	\N
[smoot]	no	misc	Smoot	\N	length	[in_i]	67	67	\N	\N	\N
bit_s	no	infotech	bit	bit	amount of information	ld(1 1)	\N	\n         	ld	1	1
bit	yes	infotech	bit	bit	amount of information	1	1	1	\N	\N	\N
By	yes	infotech	byte	B	amount of information	bit	8	8	\N	\N	\N
Bd	yes	infotech	baud	Bd	signal transmission rate	/s	1	1	\N	\N	\N
\.


--
-- Data for Name: valueset; Type: TABLE DATA; Schema: public; Owner: -
--

COPY valueset (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


--
-- Data for Name: valueset_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY valueset_history (version_id, logical_id, resource_type, updated, published, category, content) FROM stdin;
\.


SET search_path = fhir, pg_catalog;

--
-- Name: datatype_elements_pkey; Type: CONSTRAINT; Schema: fhir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY datatype_elements
    ADD CONSTRAINT datatype_elements_pkey PRIMARY KEY (datatype, name);


--
-- Name: datatype_enums_pkey; Type: CONSTRAINT; Schema: fhir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY datatype_enums
    ADD CONSTRAINT datatype_enums_pkey PRIMARY KEY (datatype, value);


--
-- Name: datatypes_pkey; Type: CONSTRAINT; Schema: fhir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY datatypes
    ADD CONSTRAINT datatypes_pkey PRIMARY KEY (type);


--
-- Name: resource_elements_pkey; Type: CONSTRAINT; Schema: fhir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY resource_elements
    ADD CONSTRAINT resource_elements_pkey PRIMARY KEY (path);


--
-- Name: resource_search_params_pkey; Type: CONSTRAINT; Schema: fhir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY resource_search_params
    ADD CONSTRAINT resource_search_params_pkey PRIMARY KEY (_id);


SET search_path = public, pg_catalog;

--
-- Name: adversereaction_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY adversereaction_history
    ADD CONSTRAINT adversereaction_history_pkey PRIMARY KEY (version_id);


--
-- Name: adversereaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY adversereaction
    ADD CONSTRAINT adversereaction_pkey PRIMARY KEY (logical_id);


--
-- Name: adversereaction_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY adversereaction
    ADD CONSTRAINT adversereaction_version_id_key UNIQUE (version_id);


--
-- Name: alert_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY alert_history
    ADD CONSTRAINT alert_history_pkey PRIMARY KEY (version_id);


--
-- Name: alert_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_pkey PRIMARY KEY (logical_id);


--
-- Name: alert_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_version_id_key UNIQUE (version_id);


--
-- Name: allergyintolerance_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY allergyintolerance_history
    ADD CONSTRAINT allergyintolerance_history_pkey PRIMARY KEY (version_id);


--
-- Name: allergyintolerance_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY allergyintolerance
    ADD CONSTRAINT allergyintolerance_pkey PRIMARY KEY (logical_id);


--
-- Name: allergyintolerance_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY allergyintolerance
    ADD CONSTRAINT allergyintolerance_version_id_key UNIQUE (version_id);


--
-- Name: careplan_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY careplan_history
    ADD CONSTRAINT careplan_history_pkey PRIMARY KEY (version_id);


--
-- Name: careplan_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY careplan
    ADD CONSTRAINT careplan_pkey PRIMARY KEY (logical_id);


--
-- Name: careplan_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY careplan
    ADD CONSTRAINT careplan_version_id_key UNIQUE (version_id);


--
-- Name: composition_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY composition_history
    ADD CONSTRAINT composition_history_pkey PRIMARY KEY (version_id);


--
-- Name: composition_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY composition
    ADD CONSTRAINT composition_pkey PRIMARY KEY (logical_id);


--
-- Name: composition_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY composition
    ADD CONSTRAINT composition_version_id_key UNIQUE (version_id);


--
-- Name: conceptmap_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY conceptmap_history
    ADD CONSTRAINT conceptmap_history_pkey PRIMARY KEY (version_id);


--
-- Name: conceptmap_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY conceptmap
    ADD CONSTRAINT conceptmap_pkey PRIMARY KEY (logical_id);


--
-- Name: conceptmap_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY conceptmap
    ADD CONSTRAINT conceptmap_version_id_key UNIQUE (version_id);


--
-- Name: condition_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY condition_history
    ADD CONSTRAINT condition_history_pkey PRIMARY KEY (version_id);


--
-- Name: condition_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY condition
    ADD CONSTRAINT condition_pkey PRIMARY KEY (logical_id);


--
-- Name: condition_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY condition
    ADD CONSTRAINT condition_version_id_key UNIQUE (version_id);


--
-- Name: conformance_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY conformance_history
    ADD CONSTRAINT conformance_history_pkey PRIMARY KEY (version_id);


--
-- Name: conformance_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY conformance
    ADD CONSTRAINT conformance_pkey PRIMARY KEY (logical_id);


--
-- Name: conformance_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY conformance
    ADD CONSTRAINT conformance_version_id_key UNIQUE (version_id);


--
-- Name: device_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY device_history
    ADD CONSTRAINT device_history_pkey PRIMARY KEY (version_id);


--
-- Name: device_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY device
    ADD CONSTRAINT device_pkey PRIMARY KEY (logical_id);


--
-- Name: device_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY device
    ADD CONSTRAINT device_version_id_key UNIQUE (version_id);


--
-- Name: deviceobservationreport_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY deviceobservationreport_history
    ADD CONSTRAINT deviceobservationreport_history_pkey PRIMARY KEY (version_id);


--
-- Name: deviceobservationreport_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY deviceobservationreport
    ADD CONSTRAINT deviceobservationreport_pkey PRIMARY KEY (logical_id);


--
-- Name: deviceobservationreport_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY deviceobservationreport
    ADD CONSTRAINT deviceobservationreport_version_id_key UNIQUE (version_id);


--
-- Name: diagnosticorder_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY diagnosticorder_history
    ADD CONSTRAINT diagnosticorder_history_pkey PRIMARY KEY (version_id);


--
-- Name: diagnosticorder_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY diagnosticorder
    ADD CONSTRAINT diagnosticorder_pkey PRIMARY KEY (logical_id);


--
-- Name: diagnosticorder_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY diagnosticorder
    ADD CONSTRAINT diagnosticorder_version_id_key UNIQUE (version_id);


--
-- Name: diagnosticreport_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY diagnosticreport_history
    ADD CONSTRAINT diagnosticreport_history_pkey PRIMARY KEY (version_id);


--
-- Name: diagnosticreport_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY diagnosticreport
    ADD CONSTRAINT diagnosticreport_pkey PRIMARY KEY (logical_id);


--
-- Name: diagnosticreport_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY diagnosticreport
    ADD CONSTRAINT diagnosticreport_version_id_key UNIQUE (version_id);


--
-- Name: documentmanifest_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY documentmanifest_history
    ADD CONSTRAINT documentmanifest_history_pkey PRIMARY KEY (version_id);


--
-- Name: documentmanifest_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY documentmanifest
    ADD CONSTRAINT documentmanifest_pkey PRIMARY KEY (logical_id);


--
-- Name: documentmanifest_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY documentmanifest
    ADD CONSTRAINT documentmanifest_version_id_key UNIQUE (version_id);


--
-- Name: documentreference_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY documentreference_history
    ADD CONSTRAINT documentreference_history_pkey PRIMARY KEY (version_id);


--
-- Name: documentreference_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY documentreference
    ADD CONSTRAINT documentreference_pkey PRIMARY KEY (logical_id);


--
-- Name: documentreference_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY documentreference
    ADD CONSTRAINT documentreference_version_id_key UNIQUE (version_id);


--
-- Name: encounter_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY encounter_history
    ADD CONSTRAINT encounter_history_pkey PRIMARY KEY (version_id);


--
-- Name: encounter_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY encounter
    ADD CONSTRAINT encounter_pkey PRIMARY KEY (logical_id);


--
-- Name: encounter_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY encounter
    ADD CONSTRAINT encounter_version_id_key UNIQUE (version_id);


--
-- Name: familyhistory_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY familyhistory_history
    ADD CONSTRAINT familyhistory_history_pkey PRIMARY KEY (version_id);


--
-- Name: familyhistory_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY familyhistory
    ADD CONSTRAINT familyhistory_pkey PRIMARY KEY (logical_id);


--
-- Name: familyhistory_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY familyhistory
    ADD CONSTRAINT familyhistory_version_id_key UNIQUE (version_id);


--
-- Name: group_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY group_history
    ADD CONSTRAINT group_history_pkey PRIMARY KEY (version_id);


--
-- Name: group_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "group"
    ADD CONSTRAINT group_pkey PRIMARY KEY (logical_id);


--
-- Name: group_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "group"
    ADD CONSTRAINT group_version_id_key UNIQUE (version_id);


--
-- Name: imagingstudy_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY imagingstudy_history
    ADD CONSTRAINT imagingstudy_history_pkey PRIMARY KEY (version_id);


--
-- Name: imagingstudy_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY imagingstudy
    ADD CONSTRAINT imagingstudy_pkey PRIMARY KEY (logical_id);


--
-- Name: imagingstudy_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY imagingstudy
    ADD CONSTRAINT imagingstudy_version_id_key UNIQUE (version_id);


--
-- Name: immunization_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY immunization_history
    ADD CONSTRAINT immunization_history_pkey PRIMARY KEY (version_id);


--
-- Name: immunization_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY immunization
    ADD CONSTRAINT immunization_pkey PRIMARY KEY (logical_id);


--
-- Name: immunization_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY immunization
    ADD CONSTRAINT immunization_version_id_key UNIQUE (version_id);


--
-- Name: immunizationrecommendation_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY immunizationrecommendation_history
    ADD CONSTRAINT immunizationrecommendation_history_pkey PRIMARY KEY (version_id);


--
-- Name: immunizationrecommendation_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY immunizationrecommendation
    ADD CONSTRAINT immunizationrecommendation_pkey PRIMARY KEY (logical_id);


--
-- Name: immunizationrecommendation_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY immunizationrecommendation
    ADD CONSTRAINT immunizationrecommendation_version_id_key UNIQUE (version_id);


--
-- Name: list_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY list_history
    ADD CONSTRAINT list_history_pkey PRIMARY KEY (version_id);


--
-- Name: list_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY list
    ADD CONSTRAINT list_pkey PRIMARY KEY (logical_id);


--
-- Name: list_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY list
    ADD CONSTRAINT list_version_id_key UNIQUE (version_id);


--
-- Name: location_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY location_history
    ADD CONSTRAINT location_history_pkey PRIMARY KEY (version_id);


--
-- Name: location_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY location
    ADD CONSTRAINT location_pkey PRIMARY KEY (logical_id);


--
-- Name: location_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY location
    ADD CONSTRAINT location_version_id_key UNIQUE (version_id);


--
-- Name: media_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY media_history
    ADD CONSTRAINT media_history_pkey PRIMARY KEY (version_id);


--
-- Name: media_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY media
    ADD CONSTRAINT media_pkey PRIMARY KEY (logical_id);


--
-- Name: media_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY media
    ADD CONSTRAINT media_version_id_key UNIQUE (version_id);


--
-- Name: medication_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medication_history
    ADD CONSTRAINT medication_history_pkey PRIMARY KEY (version_id);


--
-- Name: medication_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medication
    ADD CONSTRAINT medication_pkey PRIMARY KEY (logical_id);


--
-- Name: medication_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medication
    ADD CONSTRAINT medication_version_id_key UNIQUE (version_id);


--
-- Name: medicationadministration_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationadministration_history
    ADD CONSTRAINT medicationadministration_history_pkey PRIMARY KEY (version_id);


--
-- Name: medicationadministration_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationadministration
    ADD CONSTRAINT medicationadministration_pkey PRIMARY KEY (logical_id);


--
-- Name: medicationadministration_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationadministration
    ADD CONSTRAINT medicationadministration_version_id_key UNIQUE (version_id);


--
-- Name: medicationdispense_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationdispense_history
    ADD CONSTRAINT medicationdispense_history_pkey PRIMARY KEY (version_id);


--
-- Name: medicationdispense_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationdispense
    ADD CONSTRAINT medicationdispense_pkey PRIMARY KEY (logical_id);


--
-- Name: medicationdispense_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationdispense
    ADD CONSTRAINT medicationdispense_version_id_key UNIQUE (version_id);


--
-- Name: medicationprescription_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationprescription_history
    ADD CONSTRAINT medicationprescription_history_pkey PRIMARY KEY (version_id);


--
-- Name: medicationprescription_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationprescription
    ADD CONSTRAINT medicationprescription_pkey PRIMARY KEY (logical_id);


--
-- Name: medicationprescription_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationprescription
    ADD CONSTRAINT medicationprescription_version_id_key UNIQUE (version_id);


--
-- Name: medicationstatement_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationstatement_history
    ADD CONSTRAINT medicationstatement_history_pkey PRIMARY KEY (version_id);


--
-- Name: medicationstatement_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationstatement
    ADD CONSTRAINT medicationstatement_pkey PRIMARY KEY (logical_id);


--
-- Name: medicationstatement_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY medicationstatement
    ADD CONSTRAINT medicationstatement_version_id_key UNIQUE (version_id);


--
-- Name: messageheader_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY messageheader_history
    ADD CONSTRAINT messageheader_history_pkey PRIMARY KEY (version_id);


--
-- Name: messageheader_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY messageheader
    ADD CONSTRAINT messageheader_pkey PRIMARY KEY (logical_id);


--
-- Name: messageheader_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY messageheader
    ADD CONSTRAINT messageheader_version_id_key UNIQUE (version_id);


--
-- Name: observation_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY observation_history
    ADD CONSTRAINT observation_history_pkey PRIMARY KEY (version_id);


--
-- Name: observation_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY observation
    ADD CONSTRAINT observation_pkey PRIMARY KEY (logical_id);


--
-- Name: observation_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY observation
    ADD CONSTRAINT observation_version_id_key UNIQUE (version_id);


--
-- Name: operationoutcome_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY operationoutcome_history
    ADD CONSTRAINT operationoutcome_history_pkey PRIMARY KEY (version_id);


--
-- Name: operationoutcome_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY operationoutcome
    ADD CONSTRAINT operationoutcome_pkey PRIMARY KEY (logical_id);


--
-- Name: operationoutcome_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY operationoutcome
    ADD CONSTRAINT operationoutcome_version_id_key UNIQUE (version_id);


--
-- Name: order_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY order_history
    ADD CONSTRAINT order_history_pkey PRIMARY KEY (version_id);


--
-- Name: order_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (logical_id);


--
-- Name: order_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "order"
    ADD CONSTRAINT order_version_id_key UNIQUE (version_id);


--
-- Name: orderresponse_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY orderresponse_history
    ADD CONSTRAINT orderresponse_history_pkey PRIMARY KEY (version_id);


--
-- Name: orderresponse_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY orderresponse
    ADD CONSTRAINT orderresponse_pkey PRIMARY KEY (logical_id);


--
-- Name: orderresponse_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY orderresponse
    ADD CONSTRAINT orderresponse_version_id_key UNIQUE (version_id);


--
-- Name: organization_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organization_history
    ADD CONSTRAINT organization_history_pkey PRIMARY KEY (version_id);


--
-- Name: organization_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (logical_id);


--
-- Name: organization_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organization
    ADD CONSTRAINT organization_version_id_key UNIQUE (version_id);


--
-- Name: other_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY other_history
    ADD CONSTRAINT other_history_pkey PRIMARY KEY (version_id);


--
-- Name: other_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY other
    ADD CONSTRAINT other_pkey PRIMARY KEY (logical_id);


--
-- Name: other_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY other
    ADD CONSTRAINT other_version_id_key UNIQUE (version_id);


--
-- Name: patient_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY patient_history
    ADD CONSTRAINT patient_history_pkey PRIMARY KEY (version_id);


--
-- Name: patient_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (logical_id);


--
-- Name: patient_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY patient
    ADD CONSTRAINT patient_version_id_key UNIQUE (version_id);


--
-- Name: practitioner_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY practitioner_history
    ADD CONSTRAINT practitioner_history_pkey PRIMARY KEY (version_id);


--
-- Name: practitioner_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY practitioner
    ADD CONSTRAINT practitioner_pkey PRIMARY KEY (logical_id);


--
-- Name: practitioner_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY practitioner
    ADD CONSTRAINT practitioner_version_id_key UNIQUE (version_id);


--
-- Name: procedure_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY procedure_history
    ADD CONSTRAINT procedure_history_pkey PRIMARY KEY (version_id);


--
-- Name: procedure_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY procedure
    ADD CONSTRAINT procedure_pkey PRIMARY KEY (logical_id);


--
-- Name: procedure_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY procedure
    ADD CONSTRAINT procedure_version_id_key UNIQUE (version_id);


--
-- Name: profile_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY profile_history
    ADD CONSTRAINT profile_history_pkey PRIMARY KEY (version_id);


--
-- Name: profile_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY profile
    ADD CONSTRAINT profile_pkey PRIMARY KEY (logical_id);


--
-- Name: profile_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY profile
    ADD CONSTRAINT profile_version_id_key UNIQUE (version_id);


--
-- Name: provenance_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY provenance_history
    ADD CONSTRAINT provenance_history_pkey PRIMARY KEY (version_id);


--
-- Name: provenance_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY provenance
    ADD CONSTRAINT provenance_pkey PRIMARY KEY (logical_id);


--
-- Name: provenance_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY provenance
    ADD CONSTRAINT provenance_version_id_key UNIQUE (version_id);


--
-- Name: query_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY query_history
    ADD CONSTRAINT query_history_pkey PRIMARY KEY (version_id);


--
-- Name: query_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY query
    ADD CONSTRAINT query_pkey PRIMARY KEY (logical_id);


--
-- Name: query_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY query
    ADD CONSTRAINT query_version_id_key UNIQUE (version_id);


--
-- Name: questionnaire_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY questionnaire_history
    ADD CONSTRAINT questionnaire_history_pkey PRIMARY KEY (version_id);


--
-- Name: questionnaire_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY questionnaire
    ADD CONSTRAINT questionnaire_pkey PRIMARY KEY (logical_id);


--
-- Name: questionnaire_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY questionnaire
    ADD CONSTRAINT questionnaire_version_id_key UNIQUE (version_id);


--
-- Name: relatedperson_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY relatedperson_history
    ADD CONSTRAINT relatedperson_history_pkey PRIMARY KEY (version_id);


--
-- Name: relatedperson_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY relatedperson
    ADD CONSTRAINT relatedperson_pkey PRIMARY KEY (logical_id);


--
-- Name: relatedperson_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY relatedperson
    ADD CONSTRAINT relatedperson_version_id_key UNIQUE (version_id);


--
-- Name: securityevent_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY securityevent_history
    ADD CONSTRAINT securityevent_history_pkey PRIMARY KEY (version_id);


--
-- Name: securityevent_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY securityevent
    ADD CONSTRAINT securityevent_pkey PRIMARY KEY (logical_id);


--
-- Name: securityevent_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY securityevent
    ADD CONSTRAINT securityevent_version_id_key UNIQUE (version_id);


--
-- Name: specimen_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY specimen_history
    ADD CONSTRAINT specimen_history_pkey PRIMARY KEY (version_id);


--
-- Name: specimen_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY specimen
    ADD CONSTRAINT specimen_pkey PRIMARY KEY (logical_id);


--
-- Name: specimen_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY specimen
    ADD CONSTRAINT specimen_version_id_key UNIQUE (version_id);


--
-- Name: substance_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY substance_history
    ADD CONSTRAINT substance_history_pkey PRIMARY KEY (version_id);


--
-- Name: substance_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY substance
    ADD CONSTRAINT substance_pkey PRIMARY KEY (logical_id);


--
-- Name: substance_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY substance
    ADD CONSTRAINT substance_version_id_key UNIQUE (version_id);


--
-- Name: supply_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY supply_history
    ADD CONSTRAINT supply_history_pkey PRIMARY KEY (version_id);


--
-- Name: supply_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY supply
    ADD CONSTRAINT supply_pkey PRIMARY KEY (logical_id);


--
-- Name: supply_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY supply
    ADD CONSTRAINT supply_version_id_key UNIQUE (version_id);


--
-- Name: valueset_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY valueset_history
    ADD CONSTRAINT valueset_history_pkey PRIMARY KEY (version_id);


--
-- Name: valueset_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY valueset
    ADD CONSTRAINT valueset_pkey PRIMARY KEY (logical_id);


--
-- Name: valueset_version_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY valueset
    ADD CONSTRAINT valueset_version_id_key UNIQUE (version_id);


SET search_path = fhir, pg_catalog;

--
-- Name: resource_indexables_resource_type_param_name_search_type_idx; Type: INDEX; Schema: fhir; Owner: -; Tablespace: 
--

CREATE INDEX resource_indexables_resource_type_param_name_search_type_idx ON resource_indexables USING btree (resource_type, param_name, search_type);


SET search_path = public, pg_catalog;

--
-- Name: adversereaction_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX adversereaction_date_date_token_idx ON adversereaction USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: adversereaction_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX adversereaction_full_text_idx ON adversereaction USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: adversereaction_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX adversereaction_logical_id_as_varchar_idx ON adversereaction USING btree (((logical_id)::character varying));


--
-- Name: adversereaction_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX adversereaction_subject_subject_token_idx ON adversereaction USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: adversereaction_substance_substance_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX adversereaction_substance_substance_token_idx ON adversereaction USING gin (index_as_reference(content, '{exposure,substance}'::text[]));


--
-- Name: adversereaction_symptom_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX adversereaction_symptom_code_token_idx ON adversereaction USING gin (index_codeableconcept_as_token(content, '{symptom,code}'::text[]));


--
-- Name: alert_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX alert_full_text_idx ON alert USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: alert_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX alert_logical_id_as_varchar_idx ON alert USING btree (((logical_id)::character varying));


--
-- Name: alert_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX alert_subject_subject_token_idx ON alert USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: allergyintolerance_date_recordeddate_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX allergyintolerance_date_recordeddate_token_idx ON allergyintolerance USING gin (index_as_string(content, '{recordedDate}'::text[]) gin_trgm_ops);


--
-- Name: allergyintolerance_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX allergyintolerance_full_text_idx ON allergyintolerance USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: allergyintolerance_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX allergyintolerance_logical_id_as_varchar_idx ON allergyintolerance USING btree (((logical_id)::character varying));


--
-- Name: allergyintolerance_recorder_recorder_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX allergyintolerance_recorder_recorder_token_idx ON allergyintolerance USING gin (index_as_reference(content, '{recorder}'::text[]));


--
-- Name: allergyintolerance_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX allergyintolerance_status_status_token_idx ON allergyintolerance USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: allergyintolerance_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX allergyintolerance_subject_subject_token_idx ON allergyintolerance USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: allergyintolerance_substance_substance_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX allergyintolerance_substance_substance_token_idx ON allergyintolerance USING gin (index_as_reference(content, '{substance}'::text[]));


--
-- Name: allergyintolerance_type_sensitivitytype_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX allergyintolerance_type_sensitivitytype_token_idx ON allergyintolerance USING gin (index_primitive_as_token(content, '{sensitivityType}'::text[]));


--
-- Name: careplan_activitycode_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_activitycode_code_token_idx ON careplan USING gin (index_codeableconcept_as_token(content, '{activity,simple,code}'::text[]));


--
-- Name: careplan_activitydate_timingperiod_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_activitydate_timingperiod_token_idx ON careplan USING gin (index_as_string(content, '{activity,simple,timingPeriod}'::text[]) gin_trgm_ops);


--
-- Name: careplan_activitydate_timingschedule_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_activitydate_timingschedule_token_idx ON careplan USING gin (index_as_string(content, '{activity,simple,timingSchedule}'::text[]) gin_trgm_ops);


--
-- Name: careplan_activitydetail_detail_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_activitydetail_detail_token_idx ON careplan USING gin (index_as_reference(content, '{activity,detail}'::text[]));


--
-- Name: careplan_condition_concern_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_condition_concern_token_idx ON careplan USING gin (index_as_reference(content, '{concern}'::text[]));


--
-- Name: careplan_date_period_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_date_period_token_idx ON careplan USING gin (index_as_string(content, '{period}'::text[]) gin_trgm_ops);


--
-- Name: careplan_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_full_text_idx ON careplan USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: careplan_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX careplan_logical_id_as_varchar_idx ON careplan USING btree (((logical_id)::character varying));


--
-- Name: careplan_participant_member_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_participant_member_token_idx ON careplan USING gin (index_as_reference(content, '{participant,member}'::text[]));


--
-- Name: careplan_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX careplan_patient_patient_token_idx ON careplan USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: composition_attester_party_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_attester_party_token_idx ON composition USING gin (index_as_reference(content, '{attester,party}'::text[]));


--
-- Name: composition_author_author_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_author_author_token_idx ON composition USING gin (index_as_reference(content, '{author}'::text[]));


--
-- Name: composition_class_class_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_class_class_token_idx ON composition USING gin (index_codeableconcept_as_token(content, '{class}'::text[]));


--
-- Name: composition_context_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_context_code_token_idx ON composition USING gin (index_codeableconcept_as_token(content, '{event,code}'::text[]));


--
-- Name: composition_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_date_date_token_idx ON composition USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: composition_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_full_text_idx ON composition USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: composition_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_identifier_identifier_token_idx ON composition USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: composition_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX composition_logical_id_as_varchar_idx ON composition USING btree (((logical_id)::character varying));


--
-- Name: composition_section_content_content_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_section_content_content_token_idx ON composition USING gin (index_as_reference(content, '{section,content}'::text[]));


--
-- Name: composition_section_type_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_section_type_code_token_idx ON composition USING gin (index_codeableconcept_as_token(content, '{section,code}'::text[]));


--
-- Name: composition_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_subject_subject_token_idx ON composition USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: composition_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX composition_type_type_token_idx ON composition USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: conceptmap_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_date_date_token_idx ON conceptmap USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: conceptmap_dependson_concept_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_dependson_concept_token_idx ON conceptmap USING gin (index_primitive_as_token(content, '{concept,dependsOn,concept}'::text[]));


--
-- Name: conceptmap_description_description_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_description_description_token_idx ON conceptmap USING gin (index_as_string(content, '{description}'::text[]) gin_trgm_ops);


--
-- Name: conceptmap_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_full_text_idx ON conceptmap USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: conceptmap_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_identifier_identifier_token_idx ON conceptmap USING gin (index_primitive_as_token(content, '{identifier}'::text[]));


--
-- Name: conceptmap_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX conceptmap_logical_id_as_varchar_idx ON conceptmap USING btree (((logical_id)::character varying));


--
-- Name: conceptmap_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_name_name_token_idx ON conceptmap USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: conceptmap_product_concept_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_product_concept_token_idx ON conceptmap USING gin (index_primitive_as_token(content, '{concept,map,product,concept}'::text[]));


--
-- Name: conceptmap_publisher_publisher_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_publisher_publisher_token_idx ON conceptmap USING gin (index_as_string(content, '{publisher}'::text[]) gin_trgm_ops);


--
-- Name: conceptmap_source_source_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_source_source_token_idx ON conceptmap USING gin (index_as_reference(content, '{source}'::text[]));


--
-- Name: conceptmap_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_status_status_token_idx ON conceptmap USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: conceptmap_system_system_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_system_system_token_idx ON conceptmap USING gin (index_primitive_as_token(content, '{concept,map,system}'::text[]));


--
-- Name: conceptmap_target_target_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_target_target_token_idx ON conceptmap USING gin (index_as_reference(content, '{target}'::text[]));


--
-- Name: conceptmap_version_version_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conceptmap_version_version_token_idx ON conceptmap USING gin (index_primitive_as_token(content, '{version}'::text[]));


--
-- Name: condition_asserter_asserter_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_asserter_asserter_token_idx ON condition USING gin (index_as_reference(content, '{asserter}'::text[]));


--
-- Name: condition_category_category_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_category_category_token_idx ON condition USING gin (index_codeableconcept_as_token(content, '{category}'::text[]));


--
-- Name: condition_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_code_code_token_idx ON condition USING gin (index_codeableconcept_as_token(content, '{code}'::text[]));


--
-- Name: condition_date_asserted_dateasserted_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_date_asserted_dateasserted_token_idx ON condition USING gin (index_as_string(content, '{dateAsserted}'::text[]) gin_trgm_ops);


--
-- Name: condition_encounter_encounter_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_encounter_encounter_token_idx ON condition USING gin (index_as_reference(content, '{encounter}'::text[]));


--
-- Name: condition_evidence_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_evidence_code_token_idx ON condition USING gin (index_codeableconcept_as_token(content, '{evidence,code}'::text[]));


--
-- Name: condition_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_full_text_idx ON condition USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: condition_location_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_location_code_token_idx ON condition USING gin (index_codeableconcept_as_token(content, '{location,code}'::text[]));


--
-- Name: condition_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX condition_logical_id_as_varchar_idx ON condition USING btree (((logical_id)::character varying));


--
-- Name: condition_onset_onsetdate_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_onset_onsetdate_token_idx ON condition USING gin (index_as_string(content, '{onsetdate}'::text[]) gin_trgm_ops);


--
-- Name: condition_related_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_related_code_code_token_idx ON condition USING gin (index_codeableconcept_as_token(content, '{relatedItem,code}'::text[]));


--
-- Name: condition_related_item_target_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_related_item_target_token_idx ON condition USING gin (index_as_reference(content, '{relatedItem,target}'::text[]));


--
-- Name: condition_severity_severity_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_severity_severity_token_idx ON condition USING gin (index_codeableconcept_as_token(content, '{severity}'::text[]));


--
-- Name: condition_stage_summary_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_stage_summary_token_idx ON condition USING gin (index_codeableconcept_as_token(content, '{stage,summary}'::text[]));


--
-- Name: condition_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_status_status_token_idx ON condition USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: condition_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX condition_subject_subject_token_idx ON condition USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: conformance_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_date_date_token_idx ON conformance USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: conformance_description_description_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_description_description_token_idx ON conformance USING gin (index_as_string(content, '{description}'::text[]) gin_trgm_ops);


--
-- Name: conformance_event_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_event_code_token_idx ON conformance USING gin (index_coding_as_token(content, '{messaging,event,code}'::text[]));


--
-- Name: conformance_fhirversion_version_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_fhirversion_version_token_idx ON conformance USING gin (index_primitive_as_token(content, '{version}'::text[]));


--
-- Name: conformance_format_format_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_format_format_token_idx ON conformance USING gin (index_primitive_as_token(content, '{format}'::text[]));


--
-- Name: conformance_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_full_text_idx ON conformance USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: conformance_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_identifier_identifier_token_idx ON conformance USING gin (index_primitive_as_token(content, '{identifier}'::text[]));


--
-- Name: conformance_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX conformance_logical_id_as_varchar_idx ON conformance USING btree (((logical_id)::character varying));


--
-- Name: conformance_mode_mode_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_mode_mode_token_idx ON conformance USING gin (index_primitive_as_token(content, '{rest,mode}'::text[]));


--
-- Name: conformance_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_name_name_token_idx ON conformance USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: conformance_profile_profile_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_profile_profile_token_idx ON conformance USING gin (index_as_reference(content, '{rest,resource,profile}'::text[]));


--
-- Name: conformance_publisher_publisher_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_publisher_publisher_token_idx ON conformance USING gin (index_as_string(content, '{publisher}'::text[]) gin_trgm_ops);


--
-- Name: conformance_resource_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_resource_type_token_idx ON conformance USING gin (index_primitive_as_token(content, '{rest,resource,type}'::text[]));


--
-- Name: conformance_software_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_software_name_token_idx ON conformance USING gin (index_as_string(content, '{software,name}'::text[]) gin_trgm_ops);


--
-- Name: conformance_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_status_status_token_idx ON conformance USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: conformance_supported_profile_profile_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_supported_profile_profile_token_idx ON conformance USING gin (index_as_reference(content, '{profile}'::text[]));


--
-- Name: conformance_version_version_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX conformance_version_version_token_idx ON conformance USING gin (index_primitive_as_token(content, '{version}'::text[]));


--
-- Name: device_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_full_text_idx ON device USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: device_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_identifier_identifier_token_idx ON device USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: device_location_location_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_location_location_token_idx ON device USING gin (index_as_reference(content, '{location}'::text[]));


--
-- Name: device_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX device_logical_id_as_varchar_idx ON device USING btree (((logical_id)::character varying));


--
-- Name: device_manufacturer_manufacturer_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_manufacturer_manufacturer_token_idx ON device USING gin (index_as_string(content, '{manufacturer}'::text[]) gin_trgm_ops);


--
-- Name: device_model_model_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_model_model_token_idx ON device USING gin (index_as_string(content, '{model}'::text[]) gin_trgm_ops);


--
-- Name: device_organization_owner_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_organization_owner_token_idx ON device USING gin (index_as_reference(content, '{owner}'::text[]));


--
-- Name: device_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_patient_patient_token_idx ON device USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: device_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_type_type_token_idx ON device USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: device_udi_udi_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX device_udi_udi_token_idx ON device USING gin (index_as_string(content, '{udi}'::text[]) gin_trgm_ops);


--
-- Name: deviceobservationreport_channel_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX deviceobservationreport_channel_code_token_idx ON deviceobservationreport USING gin (index_codeableconcept_as_token(content, '{virtualDevice,channel,code}'::text[]));


--
-- Name: deviceobservationreport_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX deviceobservationreport_code_code_token_idx ON deviceobservationreport USING gin (index_codeableconcept_as_token(content, '{virtualDevice,code}'::text[]));


--
-- Name: deviceobservationreport_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX deviceobservationreport_full_text_idx ON deviceobservationreport USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: deviceobservationreport_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX deviceobservationreport_logical_id_as_varchar_idx ON deviceobservationreport USING btree (((logical_id)::character varying));


--
-- Name: deviceobservationreport_observation_observation_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX deviceobservationreport_observation_observation_token_idx ON deviceobservationreport USING gin (index_as_reference(content, '{virtualDevice,channel,metric,observation}'::text[]));


--
-- Name: deviceobservationreport_source_source_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX deviceobservationreport_source_source_token_idx ON deviceobservationreport USING gin (index_as_reference(content, '{source}'::text[]));


--
-- Name: deviceobservationreport_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX deviceobservationreport_subject_subject_token_idx ON deviceobservationreport USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: diagnosticorder_bodysite_bodysite_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_bodysite_bodysite_token_idx ON diagnosticorder USING gin (index_codeableconcept_as_token(content, '{item,bodySite}'::text[]));


--
-- Name: diagnosticorder_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_code_code_token_idx ON diagnosticorder USING gin (index_codeableconcept_as_token(content, '{item,code}'::text[]));


--
-- Name: diagnosticorder_encounter_encounter_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_encounter_encounter_token_idx ON diagnosticorder USING gin (index_as_reference(content, '{encounter}'::text[]));


--
-- Name: diagnosticorder_event_date_datetime_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_event_date_datetime_token_idx ON diagnosticorder USING gin (index_as_string(content, '{event,dateTime}'::text[]) gin_trgm_ops);


--
-- Name: diagnosticorder_event_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_event_status_status_token_idx ON diagnosticorder USING gin (index_primitive_as_token(content, '{event,status}'::text[]));


--
-- Name: diagnosticorder_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_full_text_idx ON diagnosticorder USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: diagnosticorder_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_identifier_identifier_token_idx ON diagnosticorder USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: diagnosticorder_item_past_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_item_past_status_status_token_idx ON diagnosticorder USING gin (index_primitive_as_token(content, '{item,event,status}'::text[]));


--
-- Name: diagnosticorder_item_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_item_status_status_token_idx ON diagnosticorder USING gin (index_primitive_as_token(content, '{item,status}'::text[]));


--
-- Name: diagnosticorder_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX diagnosticorder_logical_id_as_varchar_idx ON diagnosticorder USING btree (((logical_id)::character varying));


--
-- Name: diagnosticorder_orderer_orderer_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_orderer_orderer_token_idx ON diagnosticorder USING gin (index_as_reference(content, '{orderer}'::text[]));


--
-- Name: diagnosticorder_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_status_status_token_idx ON diagnosticorder USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: diagnosticorder_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticorder_subject_subject_token_idx ON diagnosticorder USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: diagnosticreport_date_diagnosticdatetime_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_date_diagnosticdatetime_token_idx ON diagnosticreport USING gin (index_as_string(content, '{diagnosticdateTime}'::text[]) gin_trgm_ops);


--
-- Name: diagnosticreport_date_diagnosticperiod_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_date_diagnosticperiod_token_idx ON diagnosticreport USING gin (index_as_string(content, '{diagnosticPeriod}'::text[]) gin_trgm_ops);


--
-- Name: diagnosticreport_diagnosis_codeddiagnosis_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_diagnosis_codeddiagnosis_token_idx ON diagnosticreport USING gin (index_codeableconcept_as_token(content, '{codedDiagnosis}'::text[]));


--
-- Name: diagnosticreport_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_full_text_idx ON diagnosticreport USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: diagnosticreport_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_identifier_identifier_token_idx ON diagnosticreport USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: diagnosticreport_image_link_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_image_link_token_idx ON diagnosticreport USING gin (index_as_reference(content, '{image,link}'::text[]));


--
-- Name: diagnosticreport_issued_issued_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_issued_issued_token_idx ON diagnosticreport USING gin (index_as_string(content, '{issued}'::text[]) gin_trgm_ops);


--
-- Name: diagnosticreport_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX diagnosticreport_logical_id_as_varchar_idx ON diagnosticreport USING btree (((logical_id)::character varying));


--
-- Name: diagnosticreport_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_name_name_token_idx ON diagnosticreport USING gin (index_codeableconcept_as_token(content, '{name}'::text[]));


--
-- Name: diagnosticreport_performer_performer_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_performer_performer_token_idx ON diagnosticreport USING gin (index_as_reference(content, '{performer}'::text[]));


--
-- Name: diagnosticreport_request_requestdetail_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_request_requestdetail_token_idx ON diagnosticreport USING gin (index_as_reference(content, '{requestDetail}'::text[]));


--
-- Name: diagnosticreport_result_result_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_result_result_token_idx ON diagnosticreport USING gin (index_as_reference(content, '{result}'::text[]));


--
-- Name: diagnosticreport_service_servicecategory_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_service_servicecategory_token_idx ON diagnosticreport USING gin (index_codeableconcept_as_token(content, '{serviceCategory}'::text[]));


--
-- Name: diagnosticreport_specimen_specimen_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_specimen_specimen_token_idx ON diagnosticreport USING gin (index_as_reference(content, '{specimen}'::text[]));


--
-- Name: diagnosticreport_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_status_status_token_idx ON diagnosticreport USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: diagnosticreport_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX diagnosticreport_subject_subject_token_idx ON diagnosticreport USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: documentmanifest_author_author_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_author_author_token_idx ON documentmanifest USING gin (index_as_reference(content, '{author}'::text[]));


--
-- Name: documentmanifest_confidentiality_confidentiality_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_confidentiality_confidentiality_token_idx ON documentmanifest USING gin (index_codeableconcept_as_token(content, '{confidentiality}'::text[]));


--
-- Name: documentmanifest_content_content_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_content_content_token_idx ON documentmanifest USING gin (index_as_reference(content, '{content}'::text[]));


--
-- Name: documentmanifest_created_created_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_created_created_token_idx ON documentmanifest USING gin (index_as_string(content, '{created}'::text[]) gin_trgm_ops);


--
-- Name: documentmanifest_description_description_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_description_description_token_idx ON documentmanifest USING gin (index_as_string(content, '{description}'::text[]) gin_trgm_ops);


--
-- Name: documentmanifest_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_full_text_idx ON documentmanifest USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: documentmanifest_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX documentmanifest_logical_id_as_varchar_idx ON documentmanifest USING btree (((logical_id)::character varying));


--
-- Name: documentmanifest_recipient_recipient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_recipient_recipient_token_idx ON documentmanifest USING gin (index_as_reference(content, '{recipient}'::text[]));


--
-- Name: documentmanifest_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_status_status_token_idx ON documentmanifest USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: documentmanifest_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_subject_subject_token_idx ON documentmanifest USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: documentmanifest_supersedes_supercedes_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_supersedes_supercedes_token_idx ON documentmanifest USING gin (index_as_reference(content, '{supercedes}'::text[]));


--
-- Name: documentmanifest_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentmanifest_type_type_token_idx ON documentmanifest USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: documentreference_authenticator_authenticator_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_authenticator_authenticator_token_idx ON documentreference USING gin (index_as_reference(content, '{authenticator}'::text[]));


--
-- Name: documentreference_author_author_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_author_author_token_idx ON documentreference USING gin (index_as_reference(content, '{author}'::text[]));


--
-- Name: documentreference_class_class_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_class_class_token_idx ON documentreference USING gin (index_codeableconcept_as_token(content, '{class}'::text[]));


--
-- Name: documentreference_confidentiality_confidentiality_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_confidentiality_confidentiality_token_idx ON documentreference USING gin (index_codeableconcept_as_token(content, '{confidentiality}'::text[]));


--
-- Name: documentreference_created_created_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_created_created_token_idx ON documentreference USING gin (index_as_string(content, '{created}'::text[]) gin_trgm_ops);


--
-- Name: documentreference_custodian_custodian_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_custodian_custodian_token_idx ON documentreference USING gin (index_as_reference(content, '{custodian}'::text[]));


--
-- Name: documentreference_description_description_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_description_description_token_idx ON documentreference USING gin (index_as_string(content, '{description}'::text[]) gin_trgm_ops);


--
-- Name: documentreference_event_event_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_event_event_token_idx ON documentreference USING gin (index_codeableconcept_as_token(content, '{context,event}'::text[]));


--
-- Name: documentreference_facility_facilitytype_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_facility_facilitytype_token_idx ON documentreference USING gin (index_codeableconcept_as_token(content, '{context,facilityType}'::text[]));


--
-- Name: documentreference_format_format_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_format_format_token_idx ON documentreference USING gin (index_primitive_as_token(content, '{format}'::text[]));


--
-- Name: documentreference_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_full_text_idx ON documentreference USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: documentreference_indexed_indexed_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_indexed_indexed_token_idx ON documentreference USING gin (index_as_string(content, '{indexed}'::text[]) gin_trgm_ops);


--
-- Name: documentreference_language_primarylanguage_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_language_primarylanguage_token_idx ON documentreference USING gin (index_primitive_as_token(content, '{primaryLanguage}'::text[]));


--
-- Name: documentreference_location_location_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_location_location_token_idx ON documentreference USING gin (index_as_string(content, '{location}'::text[]) gin_trgm_ops);


--
-- Name: documentreference_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX documentreference_logical_id_as_varchar_idx ON documentreference USING btree (((logical_id)::character varying));


--
-- Name: documentreference_period_period_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_period_period_token_idx ON documentreference USING gin (index_as_string(content, '{context,period}'::text[]) gin_trgm_ops);


--
-- Name: documentreference_relatesto_target_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_relatesto_target_token_idx ON documentreference USING gin (index_as_reference(content, '{relatesTo,target}'::text[]));


--
-- Name: documentreference_relation_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_relation_code_token_idx ON documentreference USING gin (index_primitive_as_token(content, '{relatesTo,code}'::text[]));


--
-- Name: documentreference_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_status_status_token_idx ON documentreference USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: documentreference_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_subject_subject_token_idx ON documentreference USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: documentreference_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX documentreference_type_type_token_idx ON documentreference USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: encounter_date_period_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_date_period_token_idx ON encounter USING gin (index_as_string(content, '{period}'::text[]) gin_trgm_ops);


--
-- Name: encounter_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_full_text_idx ON encounter USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: encounter_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_identifier_identifier_token_idx ON encounter USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: encounter_indication_indication_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_indication_indication_token_idx ON encounter USING gin (index_as_reference(content, '{indication}'::text[]));


--
-- Name: encounter_location_location_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_location_location_token_idx ON encounter USING gin (index_as_reference(content, '{location,location}'::text[]));


--
-- Name: encounter_location_period_period_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_location_period_period_token_idx ON encounter USING gin (index_as_string(content, '{location,period}'::text[]) gin_trgm_ops);


--
-- Name: encounter_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX encounter_logical_id_as_varchar_idx ON encounter USING btree (((logical_id)::character varying));


--
-- Name: encounter_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_status_status_token_idx ON encounter USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: encounter_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX encounter_subject_subject_token_idx ON encounter USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: familyhistory_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX familyhistory_full_text_idx ON familyhistory USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: familyhistory_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX familyhistory_logical_id_as_varchar_idx ON familyhistory USING btree (((logical_id)::character varying));


--
-- Name: familyhistory_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX familyhistory_subject_subject_token_idx ON familyhistory USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: group_actual_actual_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_actual_actual_token_idx ON "group" USING gin (index_primitive_as_token(content, '{actual}'::text[]));


--
-- Name: group_characteristic_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_characteristic_code_token_idx ON "group" USING gin (index_codeableconcept_as_token(content, '{characteristic,code}'::text[]));


--
-- Name: group_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_code_code_token_idx ON "group" USING gin (index_codeableconcept_as_token(content, '{code}'::text[]));


--
-- Name: group_exclude_exclude_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_exclude_exclude_token_idx ON "group" USING gin (index_primitive_as_token(content, '{characteristic,exclude}'::text[]));


--
-- Name: group_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_full_text_idx ON "group" USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: group_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_identifier_identifier_token_idx ON "group" USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: group_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX group_logical_id_as_varchar_idx ON "group" USING btree (((logical_id)::character varying));


--
-- Name: group_member_member_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_member_member_token_idx ON "group" USING gin (index_as_reference(content, '{member}'::text[]));


--
-- Name: group_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_type_type_token_idx ON "group" USING gin (index_primitive_as_token(content, '{type}'::text[]));


--
-- Name: group_value_valueboolean_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_value_valueboolean_token_idx ON "group" USING gin (index_primitive_as_token(content, '{characteristic,valueboolean}'::text[]));


--
-- Name: group_value_valuecodeableconcept_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX group_value_valuecodeableconcept_token_idx ON "group" USING gin (index_codeableconcept_as_token(content, '{characteristic,valueCodeableConcept}'::text[]));


--
-- Name: imagingstudy_accession_accessionno_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_accession_accessionno_token_idx ON imagingstudy USING gin (index_identifier_as_token(content, '{accessionNo}'::text[]));


--
-- Name: imagingstudy_bodysite_bodysite_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_bodysite_bodysite_token_idx ON imagingstudy USING gin (index_coding_as_token(content, '{series,bodySite}'::text[]));


--
-- Name: imagingstudy_date_datetime_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_date_datetime_token_idx ON imagingstudy USING gin (index_as_string(content, '{dateTime}'::text[]) gin_trgm_ops);


--
-- Name: imagingstudy_dicom_class_sopclass_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_dicom_class_sopclass_token_idx ON imagingstudy USING gin (index_primitive_as_token(content, '{series,instance,sopclass}'::text[]));


--
-- Name: imagingstudy_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_full_text_idx ON imagingstudy USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: imagingstudy_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX imagingstudy_logical_id_as_varchar_idx ON imagingstudy USING btree (((logical_id)::character varying));


--
-- Name: imagingstudy_modality_modality_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_modality_modality_token_idx ON imagingstudy USING gin (index_primitive_as_token(content, '{series,modality}'::text[]));


--
-- Name: imagingstudy_series_uid_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_series_uid_token_idx ON imagingstudy USING gin (index_primitive_as_token(content, '{series,uid}'::text[]));


--
-- Name: imagingstudy_study_uid_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_study_uid_token_idx ON imagingstudy USING gin (index_primitive_as_token(content, '{uid}'::text[]));


--
-- Name: imagingstudy_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_subject_subject_token_idx ON imagingstudy USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: imagingstudy_uid_uid_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX imagingstudy_uid_uid_token_idx ON imagingstudy USING gin (index_primitive_as_token(content, '{series,instance,uid}'::text[]));


--
-- Name: immunization_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_date_date_token_idx ON immunization USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: immunization_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_full_text_idx ON immunization USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: immunization_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_identifier_identifier_token_idx ON immunization USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: immunization_location_location_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_location_location_token_idx ON immunization USING gin (index_as_reference(content, '{location}'::text[]));


--
-- Name: immunization_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX immunization_logical_id_as_varchar_idx ON immunization USING btree (((logical_id)::character varying));


--
-- Name: immunization_lot_number_lotnumber_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_lot_number_lotnumber_token_idx ON immunization USING gin (index_as_string(content, '{lotNumber}'::text[]) gin_trgm_ops);


--
-- Name: immunization_manufacturer_manufacturer_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_manufacturer_manufacturer_token_idx ON immunization USING gin (index_as_reference(content, '{manufacturer}'::text[]));


--
-- Name: immunization_performer_performer_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_performer_performer_token_idx ON immunization USING gin (index_as_reference(content, '{performer}'::text[]));


--
-- Name: immunization_reaction_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_reaction_date_date_token_idx ON immunization USING gin (index_as_string(content, '{reaction,date}'::text[]) gin_trgm_ops);


--
-- Name: immunization_reaction_detail_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_reaction_detail_token_idx ON immunization USING gin (index_as_reference(content, '{reaction,detail}'::text[]));


--
-- Name: immunization_reason_reason_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_reason_reason_token_idx ON immunization USING gin (index_codeableconcept_as_token(content, '{explanation,reason}'::text[]));


--
-- Name: immunization_refusal_reason_refusalreason_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_refusal_reason_refusalreason_token_idx ON immunization USING gin (index_codeableconcept_as_token(content, '{explanation,refusalReason}'::text[]));


--
-- Name: immunization_refused_refusedindicator_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_refused_refusedindicator_token_idx ON immunization USING gin (index_primitive_as_token(content, '{refusedIndicator}'::text[]));


--
-- Name: immunization_requester_requester_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_requester_requester_token_idx ON immunization USING gin (index_as_reference(content, '{requester}'::text[]));


--
-- Name: immunization_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_subject_subject_token_idx ON immunization USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: immunization_vaccine_type_vaccinetype_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunization_vaccine_type_vaccinetype_token_idx ON immunization USING gin (index_codeableconcept_as_token(content, '{vaccineType}'::text[]));


--
-- Name: immunizationrecommendation_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_date_date_token_idx ON immunizationrecommendation USING gin (index_as_string(content, '{recommendation,date}'::text[]) gin_trgm_ops);


--
-- Name: immunizationrecommendation_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_full_text_idx ON immunizationrecommendation USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: immunizationrecommendation_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_identifier_identifier_token_idx ON immunizationrecommendation USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: immunizationrecommendation_information_supportingpatientinforma; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_information_supportingpatientinforma ON immunizationrecommendation USING gin (index_as_reference(content, '{recommendation,supportingPatientInformation}'::text[]));


--
-- Name: immunizationrecommendation_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX immunizationrecommendation_logical_id_as_varchar_idx ON immunizationrecommendation USING btree (((logical_id)::character varying));


--
-- Name: immunizationrecommendation_status_forecaststatus_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_status_forecaststatus_token_idx ON immunizationrecommendation USING gin (index_codeableconcept_as_token(content, '{recommendation,forecastStatus}'::text[]));


--
-- Name: immunizationrecommendation_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_subject_subject_token_idx ON immunizationrecommendation USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: immunizationrecommendation_support_supportingimmunization_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_support_supportingimmunization_token ON immunizationrecommendation USING gin (index_as_reference(content, '{recommendation,supportingImmunization}'::text[]));


--
-- Name: immunizationrecommendation_vaccine_type_vaccinetype_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX immunizationrecommendation_vaccine_type_vaccinetype_token_idx ON immunizationrecommendation USING gin (index_codeableconcept_as_token(content, '{recommendation,vaccineType}'::text[]));


--
-- Name: list_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX list_code_code_token_idx ON list USING gin (index_codeableconcept_as_token(content, '{code}'::text[]));


--
-- Name: list_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX list_date_date_token_idx ON list USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: list_empty_reason_emptyreason_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX list_empty_reason_emptyreason_token_idx ON list USING gin (index_codeableconcept_as_token(content, '{emptyReason}'::text[]));


--
-- Name: list_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX list_full_text_idx ON list USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: list_item_item_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX list_item_item_token_idx ON list USING gin (index_as_reference(content, '{entry,item}'::text[]));


--
-- Name: list_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX list_logical_id_as_varchar_idx ON list USING btree (((logical_id)::character varying));


--
-- Name: list_source_source_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX list_source_source_token_idx ON list USING gin (index_as_reference(content, '{source}'::text[]));


--
-- Name: list_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX list_subject_subject_token_idx ON list USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: location_address_address_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX location_address_address_token_idx ON location USING gin (index_as_string(content, '{address}'::text[]) gin_trgm_ops);


--
-- Name: location_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX location_full_text_idx ON location USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: location_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX location_identifier_identifier_token_idx ON location USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: location_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX location_logical_id_as_varchar_idx ON location USING btree (((logical_id)::character varying));


--
-- Name: location_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX location_name_name_token_idx ON location USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: location_partof_partof_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX location_partof_partof_token_idx ON location USING gin (index_as_reference(content, '{partOf}'::text[]));


--
-- Name: location_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX location_status_status_token_idx ON location USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: location_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX location_type_type_token_idx ON location USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: media_date_datetime_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_date_datetime_token_idx ON media USING gin (index_as_string(content, '{dateTime}'::text[]) gin_trgm_ops);


--
-- Name: media_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_full_text_idx ON media USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: media_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_identifier_identifier_token_idx ON media USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: media_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX media_logical_id_as_varchar_idx ON media USING btree (((logical_id)::character varying));


--
-- Name: media_operator_operator_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_operator_operator_token_idx ON media USING gin (index_as_reference(content, '{operator}'::text[]));


--
-- Name: media_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_subject_subject_token_idx ON media USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: media_subtype_subtype_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_subtype_subtype_token_idx ON media USING gin (index_codeableconcept_as_token(content, '{subtype}'::text[]));


--
-- Name: media_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_type_type_token_idx ON media USING gin (index_primitive_as_token(content, '{type}'::text[]));


--
-- Name: media_view_view_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX media_view_view_token_idx ON media USING gin (index_codeableconcept_as_token(content, '{view}'::text[]));


--
-- Name: medication_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_code_code_token_idx ON medication USING gin (index_codeableconcept_as_token(content, '{code}'::text[]));


--
-- Name: medication_container_container_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_container_container_token_idx ON medication USING gin (index_codeableconcept_as_token(content, '{package,container}'::text[]));


--
-- Name: medication_content_item_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_content_item_token_idx ON medication USING gin (index_as_reference(content, '{package,content,item}'::text[]));


--
-- Name: medication_form_form_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_form_form_token_idx ON medication USING gin (index_codeableconcept_as_token(content, '{product,form}'::text[]));


--
-- Name: medication_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_full_text_idx ON medication USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: medication_ingredient_item_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_ingredient_item_token_idx ON medication USING gin (index_as_reference(content, '{product,ingredient,item}'::text[]));


--
-- Name: medication_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX medication_logical_id_as_varchar_idx ON medication USING btree (((logical_id)::character varying));


--
-- Name: medication_manufacturer_manufacturer_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_manufacturer_manufacturer_token_idx ON medication USING gin (index_as_reference(content, '{manufacturer}'::text[]));


--
-- Name: medication_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medication_name_name_token_idx ON medication USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: medicationadministration_device_device_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_device_device_token_idx ON medicationadministration USING gin (index_as_reference(content, '{device}'::text[]));


--
-- Name: medicationadministration_encounter_encounter_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_encounter_encounter_token_idx ON medicationadministration USING gin (index_as_reference(content, '{encounter}'::text[]));


--
-- Name: medicationadministration_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_full_text_idx ON medicationadministration USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: medicationadministration_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_identifier_identifier_token_idx ON medicationadministration USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: medicationadministration_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX medicationadministration_logical_id_as_varchar_idx ON medicationadministration USING btree (((logical_id)::character varying));


--
-- Name: medicationadministration_medication_medication_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_medication_medication_token_idx ON medicationadministration USING gin (index_as_reference(content, '{medication}'::text[]));


--
-- Name: medicationadministration_notgiven_wasnotgiven_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_notgiven_wasnotgiven_token_idx ON medicationadministration USING gin (index_primitive_as_token(content, '{wasNotGiven}'::text[]));


--
-- Name: medicationadministration_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_patient_patient_token_idx ON medicationadministration USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: medicationadministration_prescription_prescription_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_prescription_prescription_token_idx ON medicationadministration USING gin (index_as_reference(content, '{prescription}'::text[]));


--
-- Name: medicationadministration_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_status_status_token_idx ON medicationadministration USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: medicationadministration_whengiven_whengiven_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationadministration_whengiven_whengiven_token_idx ON medicationadministration USING gin (index_as_string(content, '{whenGiven}'::text[]) gin_trgm_ops);


--
-- Name: medicationdispense_destination_destination_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_destination_destination_token_idx ON medicationdispense USING gin (index_as_reference(content, '{dispense,destination}'::text[]));


--
-- Name: medicationdispense_dispenser_dispenser_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_dispenser_dispenser_token_idx ON medicationdispense USING gin (index_as_reference(content, '{dispenser}'::text[]));


--
-- Name: medicationdispense_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_full_text_idx ON medicationdispense USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: medicationdispense_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_identifier_identifier_token_idx ON medicationdispense USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: medicationdispense_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX medicationdispense_logical_id_as_varchar_idx ON medicationdispense USING btree (((logical_id)::character varying));


--
-- Name: medicationdispense_medication_medication_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_medication_medication_token_idx ON medicationdispense USING gin (index_as_reference(content, '{dispense,medication}'::text[]));


--
-- Name: medicationdispense_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_patient_patient_token_idx ON medicationdispense USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: medicationdispense_prescription_authorizingprescription_token_i; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_prescription_authorizingprescription_token_i ON medicationdispense USING gin (index_as_reference(content, '{authorizingPrescription}'::text[]));


--
-- Name: medicationdispense_responsibleparty_responsibleparty_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_responsibleparty_responsibleparty_token_idx ON medicationdispense USING gin (index_as_reference(content, '{substitution,responsibleParty}'::text[]));


--
-- Name: medicationdispense_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_status_status_token_idx ON medicationdispense USING gin (index_primitive_as_token(content, '{dispense,status}'::text[]));


--
-- Name: medicationdispense_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_type_type_token_idx ON medicationdispense USING gin (index_codeableconcept_as_token(content, '{dispense,type}'::text[]));


--
-- Name: medicationdispense_whenhandedover_whenhandedover_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_whenhandedover_whenhandedover_token_idx ON medicationdispense USING gin (index_as_string(content, '{dispense,whenHandedOver}'::text[]) gin_trgm_ops);


--
-- Name: medicationdispense_whenprepared_whenprepared_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationdispense_whenprepared_whenprepared_token_idx ON medicationdispense USING gin (index_as_string(content, '{dispense,whenPrepared}'::text[]) gin_trgm_ops);


--
-- Name: medicationprescription_datewritten_datewritten_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationprescription_datewritten_datewritten_token_idx ON medicationprescription USING gin (index_as_string(content, '{dateWritten}'::text[]) gin_trgm_ops);


--
-- Name: medicationprescription_encounter_encounter_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationprescription_encounter_encounter_token_idx ON medicationprescription USING gin (index_as_reference(content, '{encounter}'::text[]));


--
-- Name: medicationprescription_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationprescription_full_text_idx ON medicationprescription USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: medicationprescription_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationprescription_identifier_identifier_token_idx ON medicationprescription USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: medicationprescription_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX medicationprescription_logical_id_as_varchar_idx ON medicationprescription USING btree (((logical_id)::character varying));


--
-- Name: medicationprescription_medication_medication_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationprescription_medication_medication_token_idx ON medicationprescription USING gin (index_as_reference(content, '{medication}'::text[]));


--
-- Name: medicationprescription_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationprescription_patient_patient_token_idx ON medicationprescription USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: medicationprescription_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationprescription_status_status_token_idx ON medicationprescription USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: medicationstatement_device_device_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationstatement_device_device_token_idx ON medicationstatement USING gin (index_as_reference(content, '{device}'::text[]));


--
-- Name: medicationstatement_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationstatement_full_text_idx ON medicationstatement USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: medicationstatement_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationstatement_identifier_identifier_token_idx ON medicationstatement USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: medicationstatement_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX medicationstatement_logical_id_as_varchar_idx ON medicationstatement USING btree (((logical_id)::character varying));


--
-- Name: medicationstatement_medication_medication_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationstatement_medication_medication_token_idx ON medicationstatement USING gin (index_as_reference(content, '{medication}'::text[]));


--
-- Name: medicationstatement_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationstatement_patient_patient_token_idx ON medicationstatement USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: medicationstatement_when_given_whengiven_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX medicationstatement_when_given_whengiven_token_idx ON medicationstatement USING gin (index_as_string(content, '{whenGiven}'::text[]) gin_trgm_ops);


--
-- Name: messageheader_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX messageheader_full_text_idx ON messageheader USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: messageheader_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX messageheader_logical_id_as_varchar_idx ON messageheader USING btree (((logical_id)::character varying));


--
-- Name: observation_date_appliesdatetime_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_date_appliesdatetime_token_idx ON observation USING gin (index_as_string(content, '{appliesdateTime}'::text[]) gin_trgm_ops);


--
-- Name: observation_date_appliesperiod_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_date_appliesperiod_token_idx ON observation USING gin (index_as_string(content, '{appliesPeriod}'::text[]) gin_trgm_ops);


--
-- Name: observation_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_full_text_idx ON observation USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: observation_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX observation_logical_id_as_varchar_idx ON observation USING btree (((logical_id)::character varying));


--
-- Name: observation_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_name_name_token_idx ON observation USING gin (index_codeableconcept_as_token(content, '{name}'::text[]));


--
-- Name: observation_performer_performer_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_performer_performer_token_idx ON observation USING gin (index_as_reference(content, '{performer}'::text[]));


--
-- Name: observation_related_target_target_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_related_target_target_token_idx ON observation USING gin (index_as_reference(content, '{related,target}'::text[]));


--
-- Name: observation_related_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_related_type_type_token_idx ON observation USING gin (index_primitive_as_token(content, '{related,type}'::text[]));


--
-- Name: observation_reliability_reliability_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_reliability_reliability_token_idx ON observation USING gin (index_primitive_as_token(content, '{reliability}'::text[]));


--
-- Name: observation_specimen_specimen_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_specimen_specimen_token_idx ON observation USING gin (index_as_reference(content, '{specimen}'::text[]));


--
-- Name: observation_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_status_status_token_idx ON observation USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: observation_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_subject_subject_token_idx ON observation USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: observation_value_concept_valuecodeableconcept_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_concept_valuecodeableconcept_token_idx ON observation USING gin (index_codeableconcept_as_token(content, '{valueCodeableConcept}'::text[]));


--
-- Name: observation_value_concept_valuestring_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_concept_valuestring_token_idx ON observation USING gin (index_primitive_as_token(content, '{valuestring}'::text[]));


--
-- Name: observation_value_date_valueperiod_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_date_valueperiod_token_idx ON observation USING gin (index_as_string(content, '{valuePeriod}'::text[]) gin_trgm_ops);


--
-- Name: observation_value_string_valueattachment_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_string_valueattachment_token_idx ON observation USING gin (index_as_string(content, '{valueAttachment}'::text[]) gin_trgm_ops);


--
-- Name: observation_value_string_valuecodeableconcept_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_string_valuecodeableconcept_token_idx ON observation USING gin (index_as_string(content, '{valueCodeableConcept}'::text[]) gin_trgm_ops);


--
-- Name: observation_value_string_valueperiod_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_string_valueperiod_token_idx ON observation USING gin (index_as_string(content, '{valuePeriod}'::text[]) gin_trgm_ops);


--
-- Name: observation_value_string_valuequantity_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_string_valuequantity_token_idx ON observation USING gin (index_as_string(content, '{valueQuantity}'::text[]) gin_trgm_ops);


--
-- Name: observation_value_string_valueratio_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_string_valueratio_token_idx ON observation USING gin (index_as_string(content, '{valueRatio}'::text[]) gin_trgm_ops);


--
-- Name: observation_value_string_valuesampleddata_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_string_valuesampleddata_token_idx ON observation USING gin (index_as_string(content, '{valueSampledData}'::text[]) gin_trgm_ops);


--
-- Name: observation_value_string_valuestring_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX observation_value_string_valuestring_token_idx ON observation USING gin (index_as_string(content, '{valuestring}'::text[]) gin_trgm_ops);


--
-- Name: operationoutcome_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX operationoutcome_full_text_idx ON operationoutcome USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: operationoutcome_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX operationoutcome_logical_id_as_varchar_idx ON operationoutcome USING btree (((logical_id)::character varying));


--
-- Name: order_authority_authority_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_authority_authority_token_idx ON "order" USING gin (index_as_reference(content, '{authority}'::text[]));


--
-- Name: order_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_date_date_token_idx ON "order" USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: order_detail_detail_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_detail_detail_token_idx ON "order" USING gin (index_as_reference(content, '{detail}'::text[]));


--
-- Name: order_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_full_text_idx ON "order" USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: order_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX order_logical_id_as_varchar_idx ON "order" USING btree (((logical_id)::character varying));


--
-- Name: order_source_source_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_source_source_token_idx ON "order" USING gin (index_as_reference(content, '{source}'::text[]));


--
-- Name: order_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_subject_subject_token_idx ON "order" USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: order_target_target_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_target_target_token_idx ON "order" USING gin (index_as_reference(content, '{target}'::text[]));


--
-- Name: order_when_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_when_code_code_token_idx ON "order" USING gin (index_codeableconcept_as_token(content, '{when,code}'::text[]));


--
-- Name: order_when_schedule_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX order_when_schedule_token_idx ON "order" USING gin (index_as_string(content, '{when,schedule}'::text[]) gin_trgm_ops);


--
-- Name: orderresponse_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX orderresponse_code_code_token_idx ON orderresponse USING gin (index_primitive_as_token(content, '{code}'::text[]));


--
-- Name: orderresponse_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX orderresponse_date_date_token_idx ON orderresponse USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: orderresponse_fulfillment_fulfillment_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX orderresponse_fulfillment_fulfillment_token_idx ON orderresponse USING gin (index_as_reference(content, '{fulfillment}'::text[]));


--
-- Name: orderresponse_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX orderresponse_full_text_idx ON orderresponse USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: orderresponse_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX orderresponse_logical_id_as_varchar_idx ON orderresponse USING btree (((logical_id)::character varying));


--
-- Name: orderresponse_request_request_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX orderresponse_request_request_token_idx ON orderresponse USING gin (index_as_reference(content, '{request}'::text[]));


--
-- Name: orderresponse_who_who_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX orderresponse_who_who_token_idx ON orderresponse USING gin (index_as_reference(content, '{who}'::text[]));


--
-- Name: organization_active_active_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organization_active_active_token_idx ON organization USING gin (index_primitive_as_token(content, '{active}'::text[]));


--
-- Name: organization_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organization_full_text_idx ON organization USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: organization_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organization_identifier_identifier_token_idx ON organization USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: organization_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX organization_logical_id_as_varchar_idx ON organization USING btree (((logical_id)::character varying));


--
-- Name: organization_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organization_name_name_token_idx ON organization USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: organization_partof_partof_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organization_partof_partof_token_idx ON organization USING gin (index_as_reference(content, '{partOf}'::text[]));


--
-- Name: organization_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX organization_type_type_token_idx ON organization USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: other_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX other_code_code_token_idx ON other USING gin (index_codeableconcept_as_token(content, '{code}'::text[]));


--
-- Name: other_created_created_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX other_created_created_token_idx ON other USING gin (index_as_string(content, '{created}'::text[]) gin_trgm_ops);


--
-- Name: other_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX other_full_text_idx ON other USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: other_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX other_logical_id_as_varchar_idx ON other USING btree (((logical_id)::character varying));


--
-- Name: other_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX other_subject_subject_token_idx ON other USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: patient_active_active_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_active_active_token_idx ON patient USING gin (index_primitive_as_token(content, '{active}'::text[]));


--
-- Name: patient_address_address_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_address_address_token_idx ON patient USING gin (index_as_string(content, '{address}'::text[]) gin_trgm_ops);


--
-- Name: patient_animal_breed_breed_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_animal_breed_breed_token_idx ON patient USING gin (index_codeableconcept_as_token(content, '{animal,breed}'::text[]));


--
-- Name: patient_animal_species_species_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_animal_species_species_token_idx ON patient USING gin (index_codeableconcept_as_token(content, '{animal,species}'::text[]));


--
-- Name: patient_birthdate_birthdate_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_birthdate_birthdate_token_idx ON patient USING gin (index_as_string(content, '{birthDate}'::text[]) gin_trgm_ops);


--
-- Name: patient_family_family_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_family_family_token_idx ON patient USING gin (index_as_string(content, '{name,family}'::text[]) gin_trgm_ops);


--
-- Name: patient_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_full_text_idx ON patient USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: patient_gender_gender_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_gender_gender_token_idx ON patient USING gin (index_codeableconcept_as_token(content, '{gender}'::text[]));


--
-- Name: patient_given_given_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_given_given_token_idx ON patient USING gin (index_as_string(content, '{name,given}'::text[]) gin_trgm_ops);


--
-- Name: patient_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_identifier_identifier_token_idx ON patient USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: patient_language_communication_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_language_communication_token_idx ON patient USING gin (index_codeableconcept_as_token(content, '{communication}'::text[]));


--
-- Name: patient_link_other_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_link_other_token_idx ON patient USING gin (index_as_reference(content, '{link,other}'::text[]));


--
-- Name: patient_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX patient_logical_id_as_varchar_idx ON patient USING btree (((logical_id)::character varying));


--
-- Name: patient_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_name_name_token_idx ON patient USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: patient_provider_managingorganization_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_provider_managingorganization_token_idx ON patient USING gin (index_as_reference(content, '{managingOrganization}'::text[]));


--
-- Name: patient_telecom_telecom_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX patient_telecom_telecom_token_idx ON patient USING gin (index_as_string(content, '{telecom}'::text[]) gin_trgm_ops);


--
-- Name: practitioner_address_address_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_address_address_token_idx ON practitioner USING gin (index_as_string(content, '{address}'::text[]) gin_trgm_ops);


--
-- Name: practitioner_family_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_family_name_token_idx ON practitioner USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: practitioner_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_full_text_idx ON practitioner USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: practitioner_gender_gender_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_gender_gender_token_idx ON practitioner USING gin (index_codeableconcept_as_token(content, '{gender}'::text[]));


--
-- Name: practitioner_given_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_given_name_token_idx ON practitioner USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: practitioner_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_identifier_identifier_token_idx ON practitioner USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: practitioner_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX practitioner_logical_id_as_varchar_idx ON practitioner USING btree (((logical_id)::character varying));


--
-- Name: practitioner_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_name_name_token_idx ON practitioner USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: practitioner_organization_organization_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_organization_organization_token_idx ON practitioner USING gin (index_as_reference(content, '{organization}'::text[]));


--
-- Name: practitioner_phonetic_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_phonetic_name_token_idx ON practitioner USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: practitioner_telecom_telecom_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX practitioner_telecom_telecom_token_idx ON practitioner USING gin (index_as_string(content, '{telecom}'::text[]) gin_trgm_ops);


--
-- Name: procedure_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX procedure_date_date_token_idx ON procedure USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: procedure_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX procedure_full_text_idx ON procedure USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: procedure_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX procedure_logical_id_as_varchar_idx ON procedure USING btree (((logical_id)::character varying));


--
-- Name: procedure_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX procedure_subject_subject_token_idx ON procedure USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: procedure_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX procedure_type_type_token_idx ON procedure USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: profile_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_code_code_token_idx ON profile USING gin (index_coding_as_token(content, '{code}'::text[]));


--
-- Name: profile_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_date_date_token_idx ON profile USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: profile_description_description_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_description_description_token_idx ON profile USING gin (index_as_string(content, '{description}'::text[]) gin_trgm_ops);


--
-- Name: profile_extension_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_extension_code_token_idx ON profile USING gin (index_primitive_as_token(content, '{extensionDefn,code}'::text[]));


--
-- Name: profile_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_full_text_idx ON profile USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: profile_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_identifier_identifier_token_idx ON profile USING gin (index_primitive_as_token(content, '{identifier}'::text[]));


--
-- Name: profile_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX profile_logical_id_as_varchar_idx ON profile USING btree (((logical_id)::character varying));


--
-- Name: profile_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_name_name_token_idx ON profile USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: profile_publisher_publisher_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_publisher_publisher_token_idx ON profile USING gin (index_as_string(content, '{publisher}'::text[]) gin_trgm_ops);


--
-- Name: profile_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_status_status_token_idx ON profile USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: profile_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_type_type_token_idx ON profile USING gin (index_primitive_as_token(content, '{structure,type}'::text[]));


--
-- Name: profile_valueset_referenceresourcereference_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_valueset_referenceresourcereference_token_idx ON profile USING gin (index_as_reference(content, '{structure,element,definition,binding,referenceResourceReference}'::text[]));


--
-- Name: profile_version_version_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX profile_version_version_token_idx ON profile USING gin (index_primitive_as_token(content, '{version}'::text[]));


--
-- Name: provenance_end_end_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX provenance_end_end_token_idx ON provenance USING gin (index_as_string(content, '{period,end}'::text[]) gin_trgm_ops);


--
-- Name: provenance_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX provenance_full_text_idx ON provenance USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: provenance_location_location_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX provenance_location_location_token_idx ON provenance USING gin (index_as_reference(content, '{location}'::text[]));


--
-- Name: provenance_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX provenance_logical_id_as_varchar_idx ON provenance USING btree (((logical_id)::character varying));


--
-- Name: provenance_party_reference_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX provenance_party_reference_token_idx ON provenance USING gin (index_primitive_as_token(content, '{agent,reference}'::text[]));


--
-- Name: provenance_partytype_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX provenance_partytype_type_token_idx ON provenance USING gin (index_coding_as_token(content, '{agent,type}'::text[]));


--
-- Name: provenance_target_target_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX provenance_target_target_token_idx ON provenance USING gin (index_as_reference(content, '{target}'::text[]));


--
-- Name: query_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX query_full_text_idx ON query USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: query_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX query_identifier_identifier_token_idx ON query USING gin (index_primitive_as_token(content, '{identifier}'::text[]));


--
-- Name: query_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX query_logical_id_as_varchar_idx ON query USING btree (((logical_id)::character varying));


--
-- Name: query_response_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX query_response_identifier_token_idx ON query USING gin (index_primitive_as_token(content, '{response,identifier}'::text[]));


--
-- Name: questionnaire_author_author_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_author_author_token_idx ON questionnaire USING gin (index_as_reference(content, '{author}'::text[]));


--
-- Name: questionnaire_authored_authored_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_authored_authored_token_idx ON questionnaire USING gin (index_as_string(content, '{authored}'::text[]) gin_trgm_ops);


--
-- Name: questionnaire_encounter_encounter_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_encounter_encounter_token_idx ON questionnaire USING gin (index_as_reference(content, '{encounter}'::text[]));


--
-- Name: questionnaire_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_full_text_idx ON questionnaire USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: questionnaire_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_identifier_identifier_token_idx ON questionnaire USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: questionnaire_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX questionnaire_logical_id_as_varchar_idx ON questionnaire USING btree (((logical_id)::character varying));


--
-- Name: questionnaire_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_name_name_token_idx ON questionnaire USING gin (index_codeableconcept_as_token(content, '{name}'::text[]));


--
-- Name: questionnaire_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_status_status_token_idx ON questionnaire USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: questionnaire_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX questionnaire_subject_subject_token_idx ON questionnaire USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: relatedperson_address_address_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX relatedperson_address_address_token_idx ON relatedperson USING gin (index_as_string(content, '{address}'::text[]) gin_trgm_ops);


--
-- Name: relatedperson_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX relatedperson_full_text_idx ON relatedperson USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: relatedperson_gender_gender_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX relatedperson_gender_gender_token_idx ON relatedperson USING gin (index_codeableconcept_as_token(content, '{gender}'::text[]));


--
-- Name: relatedperson_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX relatedperson_identifier_identifier_token_idx ON relatedperson USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: relatedperson_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX relatedperson_logical_id_as_varchar_idx ON relatedperson USING btree (((logical_id)::character varying));


--
-- Name: relatedperson_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX relatedperson_name_name_token_idx ON relatedperson USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: relatedperson_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX relatedperson_patient_patient_token_idx ON relatedperson USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: relatedperson_telecom_telecom_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX relatedperson_telecom_telecom_token_idx ON relatedperson USING gin (index_as_string(content, '{telecom}'::text[]) gin_trgm_ops);


--
-- Name: securityevent_action_action_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_action_action_token_idx ON securityevent USING gin (index_primitive_as_token(content, '{event,action}'::text[]));


--
-- Name: securityevent_address_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_address_identifier_token_idx ON securityevent USING gin (index_primitive_as_token(content, '{participant,network,identifier}'::text[]));


--
-- Name: securityevent_altid_altid_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_altid_altid_token_idx ON securityevent USING gin (index_primitive_as_token(content, '{participant,altId}'::text[]));


--
-- Name: securityevent_date_datetime_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_date_datetime_token_idx ON securityevent USING gin (index_as_string(content, '{event,dateTime}'::text[]) gin_trgm_ops);


--
-- Name: securityevent_desc_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_desc_name_token_idx ON securityevent USING gin (index_as_string(content, '{object,name}'::text[]) gin_trgm_ops);


--
-- Name: securityevent_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_full_text_idx ON securityevent USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: securityevent_identity_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_identity_identifier_token_idx ON securityevent USING gin (index_identifier_as_token(content, '{object,identifier}'::text[]));


--
-- Name: securityevent_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX securityevent_logical_id_as_varchar_idx ON securityevent USING btree (((logical_id)::character varying));


--
-- Name: securityevent_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_name_name_token_idx ON securityevent USING gin (index_as_string(content, '{participant,name}'::text[]) gin_trgm_ops);


--
-- Name: securityevent_object_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_object_type_type_token_idx ON securityevent USING gin (index_primitive_as_token(content, '{object,type}'::text[]));


--
-- Name: securityevent_reference_reference_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_reference_reference_token_idx ON securityevent USING gin (index_as_reference(content, '{object,reference}'::text[]));


--
-- Name: securityevent_site_site_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_site_site_token_idx ON securityevent USING gin (index_primitive_as_token(content, '{source,site}'::text[]));


--
-- Name: securityevent_source_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_source_identifier_token_idx ON securityevent USING gin (index_primitive_as_token(content, '{source,identifier}'::text[]));


--
-- Name: securityevent_subtype_subtype_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_subtype_subtype_token_idx ON securityevent USING gin (index_codeableconcept_as_token(content, '{event,subtype}'::text[]));


--
-- Name: securityevent_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_type_type_token_idx ON securityevent USING gin (index_codeableconcept_as_token(content, '{event,type}'::text[]));


--
-- Name: securityevent_user_userid_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX securityevent_user_userid_token_idx ON securityevent USING gin (index_primitive_as_token(content, '{participant,userId}'::text[]));


--
-- Name: specimen_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX specimen_full_text_idx ON specimen USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: specimen_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX specimen_logical_id_as_varchar_idx ON specimen USING btree (((logical_id)::character varying));


--
-- Name: specimen_subject_subject_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX specimen_subject_subject_token_idx ON specimen USING gin (index_as_reference(content, '{subject}'::text[]));


--
-- Name: substance_expiry_expiry_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX substance_expiry_expiry_token_idx ON substance USING gin (index_as_string(content, '{instance,expiry}'::text[]) gin_trgm_ops);


--
-- Name: substance_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX substance_full_text_idx ON substance USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: substance_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX substance_identifier_identifier_token_idx ON substance USING gin (index_identifier_as_token(content, '{instance,identifier}'::text[]));


--
-- Name: substance_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX substance_logical_id_as_varchar_idx ON substance USING btree (((logical_id)::character varying));


--
-- Name: substance_substance_substance_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX substance_substance_substance_token_idx ON substance USING gin (index_as_reference(content, '{ingredient,substance}'::text[]));


--
-- Name: substance_type_type_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX substance_type_type_token_idx ON substance USING gin (index_codeableconcept_as_token(content, '{type}'::text[]));


--
-- Name: supply_dispenseid_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_dispenseid_identifier_token_idx ON supply USING gin (index_identifier_as_token(content, '{dispense,identifier}'::text[]));


--
-- Name: supply_dispensestatus_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_dispensestatus_status_token_idx ON supply USING gin (index_primitive_as_token(content, '{dispense,status}'::text[]));


--
-- Name: supply_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_full_text_idx ON supply USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: supply_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_identifier_identifier_token_idx ON supply USING gin (index_identifier_as_token(content, '{identifier}'::text[]));


--
-- Name: supply_kind_kind_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_kind_kind_token_idx ON supply USING gin (index_codeableconcept_as_token(content, '{kind}'::text[]));


--
-- Name: supply_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX supply_logical_id_as_varchar_idx ON supply USING btree (((logical_id)::character varying));


--
-- Name: supply_patient_patient_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_patient_patient_token_idx ON supply USING gin (index_as_reference(content, '{patient}'::text[]));


--
-- Name: supply_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_status_status_token_idx ON supply USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: supply_supplier_supplier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX supply_supplier_supplier_token_idx ON supply USING gin (index_as_reference(content, '{dispense,supplier}'::text[]));


--
-- Name: valueset_code_code_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_code_code_token_idx ON valueset USING gin (index_primitive_as_token(content, '{define,concept,code}'::text[]));


--
-- Name: valueset_date_date_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_date_date_token_idx ON valueset USING gin (index_as_string(content, '{date}'::text[]) gin_trgm_ops);


--
-- Name: valueset_description_description_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_description_description_token_idx ON valueset USING gin (index_as_string(content, '{description}'::text[]) gin_trgm_ops);


--
-- Name: valueset_full_text_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_full_text_idx ON valueset USING gin (to_tsvector('english'::regconfig, (content)::text));


--
-- Name: valueset_identifier_identifier_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_identifier_identifier_token_idx ON valueset USING gin (index_primitive_as_token(content, '{identifier}'::text[]));


--
-- Name: valueset_logical_id_as_varchar_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX valueset_logical_id_as_varchar_idx ON valueset USING btree (((logical_id)::character varying));


--
-- Name: valueset_name_name_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_name_name_token_idx ON valueset USING gin (index_as_string(content, '{name}'::text[]) gin_trgm_ops);


--
-- Name: valueset_publisher_publisher_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_publisher_publisher_token_idx ON valueset USING gin (index_as_string(content, '{publisher}'::text[]) gin_trgm_ops);


--
-- Name: valueset_reference_system_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_reference_system_token_idx ON valueset USING gin (index_primitive_as_token(content, '{compose,include,system}'::text[]));


--
-- Name: valueset_status_status_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_status_status_token_idx ON valueset USING gin (index_primitive_as_token(content, '{status}'::text[]));


--
-- Name: valueset_system_system_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_system_system_token_idx ON valueset USING gin (index_primitive_as_token(content, '{define,system}'::text[]));


--
-- Name: valueset_version_version_token_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX valueset_version_version_token_idx ON valueset USING gin (index_primitive_as_token(content, '{version}'::text[]));


SET search_path = fhir, pg_catalog;

--
-- Name: datatype_elements_datatype_fkey; Type: FK CONSTRAINT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY datatype_elements
    ADD CONSTRAINT datatype_elements_datatype_fkey FOREIGN KEY (datatype) REFERENCES datatypes(type);


--
-- Name: datatype_enums_datatype_fkey; Type: FK CONSTRAINT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY datatype_enums
    ADD CONSTRAINT datatype_enums_datatype_fkey FOREIGN KEY (datatype) REFERENCES datatypes(type);


--
-- PostgreSQL database dump complete
--

