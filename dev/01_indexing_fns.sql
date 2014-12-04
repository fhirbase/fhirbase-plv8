--db:fhirb
-- INDEXING FUNCTIONS
-- TOKEN INDEX
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

