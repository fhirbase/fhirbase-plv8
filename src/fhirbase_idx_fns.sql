-- INDEXING FUNCTIONS
-- TOKEN INDEX
-- TODO: create facade fn like date

-- #import ./fhirbase_json.sql
-- #import ./fhirbase_coll.sql

func index_primitive_as_token( content jsonb, path text[]) RETURNS text[]
  SELECT
  array_agg(fhirbase_json.jsonb_primitive_to_text(unnest::jsonb))::text[]
  FROM unnest(fhirbase_json.json_get_in(content, path))

func index_coding_as_token( content jsonb, path text[]) RETURNS text[]
  WITH codings AS (
    SELECT unnest as cd
    FROM unnest(fhirbase_json.json_get_in(content, path))
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
    FROM unnest(fhirbase_json.json_get_in(content, path))
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
    FROM unnest(fhirbase_json.json_get_in(content, path))
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
    FROM unnest(fhirbase_json.json_get_in(content, path))
  )
  SELECT array_agg(x)::text[] FROM (
    SELECT cd->>'reference' as x
    from idents
    UNION
    SELECT fhirbase_coll._last(regexp_split_to_array(cd->>'reference', '\/')) as x
    from idents
  ) _


--TODO: this is KISS implementation
-- the simplest way is to collect only values
-- so we need collect values function
CREATE extension IF NOT EXISTS unaccent;

func _unaccent_string(_text text) RETURNS text
  -- TODO: detect extension availability
  --SELECT translate(_text,
  --  'âãäåāăąÁÂÃÄÅĀĂĄèééêëēĕėęěĒĔĖĘĚìíîïìĩīĭÌÍÎÏÌĨĪĬóôõöōŏőÒÓÔÕÖŌŎŐùúûüũūŭůÙÚÛÜŨŪŬŮ',
  --  'aaaaaaaAAAAAAAAeeeeeeeeeeEEEEEiiiiiiiiIIIIIIIIoooooooOOOOOOOOuuuuuuuuUUUUUUUU'
  --)
  SELECT unaccent(_text)::text

func _to_string(_text text) RETURNS text
  SELECT translate(_text, '"[]{}\\:,', '        ');

func index_as_string( content jsonb, path text[]) RETURNS text
  SELECT
  regexp_replace(
    this._to_string(
      this._unaccent_string(
        fhirbase_json.json_get_in(content, path)::text
       )
    )::text,
    E'\\s+', ' ', 'g'
  )
