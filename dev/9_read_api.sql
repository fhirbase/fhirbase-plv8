--db:fhirb
--{{{
DROP FUNCTION IF EXISTS read(text,uuid);
CREATE OR REPLACE FUNCTION
read(_resource_type text, _id uuid)
RETURNS TABLE(id uuid, version_id uuid, updated timestamptz, published timestamptz, content jsonb, category jsonb)
LANGUAGE sql AS $$
  SELECT   r.logical_id AS id,
           r.version_id AS version_id,
           r.updated AS updated,
           r.published AS published,
           r.content AS content,
           r.category AS category
       FROM resource r
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION
history_resource(_resource_type varchar, _id uuid)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  res record;
BEGIN
  EXECUTE
    eval_template($SQL$
      WITH entries AS
      (SELECT
          x.logical_id as id
          ,x.updated as updated
          ,x.published as published
          ,x.content as content
          ,x.category as category
        FROM "{{tbl}}" x
        WHERE x.logical_id  = $1
        UNION
        SELECT
          x.logical_id as id
          ,x.updated as updated
          ,x.published as published
          ,x.content as content
          ,x.category as category
        FROM {{tbl}}_history x
        WHERE x.logical_id  = $1)
      SELECT
        json_build_object(
          'title', 'search',
          'resourceType', 'Bundle',
          'updated', now(),
          'id', gen_random_uuid(),
          'entry', COALESCE(json_agg(y.*), '[]'::json)
        ) as json
        FROM entries y
   $SQL$, 'tbl', lower(_resource_type))
  INTO res USING _id;

  RETURN res.json;
END
$$;
--}}}
