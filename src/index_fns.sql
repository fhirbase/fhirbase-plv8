-- INDEXING FUNCTIONS
-- TOKEN INDEX
-- TODO: create facade fn like date

-- #import ./jsonbext.sql
-- #import ./coll.sql

func index_primitive_as_token( content jsonb, path text[]) RETURNS text[]
  SELECT
  array_agg(jsonbext.jsonb_primitive_to_text(unnest::jsonb))::text[]
  FROM unnest(jsonbext.json_get_in(content, path))

func index_coding_as_token( content jsonb, path text[]) RETURNS text[]
  WITH codings AS (
    SELECT unnest as cd
    FROM unnest(jsonbext.json_get_in(content, path))
  )
  SELECT array_agg(x)::text[] FROM (
    SELECT cd->>'code' as x
    from codings
    UNION
    SELECT cd->>'system' || '|' || (cd->>'code') as x
    from codings
  ) _

func index_contactpoint_as_token( content jsonb, path text[]) RETURNS text[]
  WITH codings AS (
    SELECT unnest as cd
    FROM unnest(jsonbext.json_get_in(content, path))
  )
  SELECT array_agg(x)::text[] FROM (
    SELECT cd->>'system' as x
    from codings
    UNION
    SELECT cd->>'system' || '|' || (cd->>'value') as x
    from codings
  ) _

func index_codeableconcept_as_token( content jsonb, path text[]) RETURNS text[]
  SELECT this.index_coding_as_token(content, array_append(path,'coding'))

func index_identifier_as_token(content jsonb, path text[]) RETURNS text[]
  WITH idents AS (
    SELECT unnest as cd
    FROM unnest(jsonbext.json_get_in(content, path))
  )
  SELECT array_agg(x)::text[] FROM (
    SELECT cd->>'value' as x
    from idents
    UNION
    SELECT cd->>'system' || '|' || (cd->>'value') as x
    from idents
  ) _

func index_as_reference(content jsonb, path text[]) RETURNS text[]
  WITH idents AS (
    SELECT unnest as cd
    FROM unnest(jsonbext.json_get_in(content, path))
  )
  SELECT array_agg(x)::text[] FROM (
    SELECT cd->>'reference' as x
    from idents
    UNION
    SELECT coll._last(regexp_split_to_array(cd->>'reference', '\/')) as x
    from idents
  ) _


--TODO: this is KISS implementation
-- the simplest way is to collect only values
-- so we need collect values function
func _unaccent_string(_text text) RETURNS text
  SELECT translate(_text,
    'âãäåāăąÁÂÃÄÅĀĂĄèééêëēĕėęěĒĔĖĘĚìíîïìĩīĭÌÍÎÏÌĨĪĬóôõöōŏőÒÓÔÕÖŌŎŐùúûüũūŭůÙÚÛÜŨŪŬŮ',
    'aaaaaaaAAAAAAAAeeeeeeeeeeEEEEEiiiiiiiiIIIIIIIIoooooooOOOOOOOOuuuuuuuuUUUUUUUU'
  )

func _to_string(_text text) RETURNS text
  SELECT translate(_text, '"[]{}\\:,', '        ');

func index_as_string( content jsonb, path text[]) RETURNS text
  SELECT
  regexp_replace(
    this._to_string(
      this._unaccent_string(
        jsonbext.json_get_in(content, path)::text
       )
    )::text,
    E'\\s+', ' ', 'g'
  )
