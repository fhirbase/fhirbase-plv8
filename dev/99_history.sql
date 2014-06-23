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
          ,x.last_modified_date as last_modified_date
          ,x.published as published
          ,x.data as content
        FROM "{{tbl}}" x
        WHERE x.logical_id  = $1
        UNION
        SELECT
          x.logical_id as id
          ,x.last_modified_date as last_modified_date
          ,x.published as published
          ,x.data as content
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
