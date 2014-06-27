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
           CASE WHEN string_agg(t.scheme,'') IS NULL THEN
             NULL
           ELSE
             json_agg(
                json_build_object('scheme', t.scheme,
                                  'term', t.term,
                                  'label', t.label))::jsonb
           END AS category
       FROM resource r
  LEFT JOIN tag t
         ON t.resource_id = r.logical_id
            AND t.resource_type = r.resource_type
      WHERE r.resource_type = _resource_type
        AND r.logical_id = _id
   GROUP BY r.logical_id,
            r.version_id,
            r.content,
            r.updated,
            r.published
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
        FROM "{{tbl}}" x
        WHERE x.logical_id  = $1
        UNION
        SELECT
          x.logical_id as id
          ,x.updated as updated
          ,x.published as published
          ,x.content as content
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
