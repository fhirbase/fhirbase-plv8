--db:fhirb
-- INDEXING FUNCTIONS
-- TOKEN INDEX
--{{{
/* CREATE EXTENSION IF NOT EXISTS jsonb_extra; */
/* CREATE OR REPLACE FUNCTION */
/* json_get_in(x jsonb, path text[]) */
/* RETURNS jsonb[] LANGUAGE sql AS $$ */
/*   SELECT jsonb_extract(x, path); */
/* $$ IMMUTABLE; */
--}}}

--{{{
CREATE OR REPLACE FUNCTION
jsonb_primitive_to_text(x jsonb)
RETURNS text LANGUAGE sql AS $$
  SELECT json_build_object('x', x)->>'x';
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
index_primitive_as_token( content jsonb, path text[])
RETURNS varchar[] LANGUAGE sql AS $$
  SELECT
   array_agg(jsonb_primitive_to_text(unnest::jsonb))::varchar[]
  FROM unnest(json_get_in(content, path))
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
index_coding_as_token( content jsonb, path text[])
RETURNS varchar[] LANGUAGE sql AS $$
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
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
index_codeableconcept_as_token( content jsonb, path text[])
RETURNS varchar[] LANGUAGE sql AS $$
  SELECT index_coding_as_token(content, array_append(path,'coding'));
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
index_identifier_as_token(content jsonb, path text[])
RETURNS varchar[] LANGUAGE sql AS $$
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
$$ IMMUTABLE;
--}}}

--{{{
CREATE OR REPLACE FUNCTION
index_as_reference(content jsonb, path text[])
RETURNS varchar[] LANGUAGE sql AS $$
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
$$ IMMUTABLE;
--}}}

--TODO: this is KISS implementation
-- the simplest way is to collect only values
-- so we need collect values function
--{{{
CREATE OR REPLACE FUNCTION
_unaccent_string(_text text) RETURNS text
LANGUAGE sql AS $$
  SELECT translate(_text,
    'âãäåāăąÁÂÃÄÅĀĂĄèééêëēĕėęěĒĔĖĘĚìíîïìĩīĭÌÍÎÏÌĨĪĬóôõöōŏőÒÓÔÕÖŌŎŐùúûüũūŭůÙÚÛÜŨŪŬŮ',
    'aaaaaaaAAAAAAAAeeeeeeeeeeEEEEEiiiiiiiiIIIIIIIIoooooooOOOOOOOOuuuuuuuuUUUUUUUU');
$$;

CREATE OR REPLACE FUNCTION
_to_string(_text text) RETURNS text
LANGUAGE sql AS $$
  SELECT translate(_text,
    '"[]{}\\:,',
    '        ');
$$;

CREATE OR REPLACE FUNCTION
index_as_string( content jsonb, path text[])
RETURNS text LANGUAGE sql AS $$
  SELECT
    regexp_replace(
      _to_string(_unaccent_string(json_get_in(content, path)::text))::text,
      E'\\s+', ' ', 'g')
$$ IMMUTABLE;
--}}}
