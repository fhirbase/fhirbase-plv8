drop table if exists  _valueset_expansion;
create table _valueset_expansion  (
    id serial primary key,
    valueset_id text not null,
    parent_code text,
    system text,
    code text not null,
    display text
);


-- just experiment
drop table if exists  _fhirbase_hook;
create table _fhirbase_hook  (
    id serial primary key,
    function_name text not null,
    system boolean default false,
    phase text not null,
    hook_function_name text not null,
    weight integer
);

WITH RECURSIVE concepts(vid, system, parent_code, concept, children) AS (
    SELECT  vid, system, parent_code, concept, concept->'concept'
    FROM (
      SELECT
        id as vid,
        resource#>>'{codeSystem,system}' as system,
        null::text as parent_code,
        jsonb_array_elements(resource#>'{codeSystem,concept}') as concept
      FROM valueset
      WHERE jsonb_typeof(resource#>'{codeSystem}') IS NOT NULL
    ) _

    UNION ALL
    SELECT
      vid, system, parent_code, next, next->'concept' as children from (
        select vid, system, concept->>'code' as parent_code, jsonb_array_elements(children) as next
        from concepts c
        where jsonb_typeof(children) is not null
    )  _
)
INSERT INTO _valueset_expansion (valueset_id, system, parent_code, code, display)
SELECT
vid, system, parent_code, concept->>'code' as code, concept->>'display' as display
FROM concepts;

WITH concepts(vid, system, parent_code, concept) AS (
  SELECT
      vid,
      system as system,
      null::text as parent_code,
      concept as concept
  FROM (
      SELECT
        vid,
        include->>'system' as system,
        jsonb_array_elements(include#>'{concept}') as concept
        FROM (
          SELECT
            id as vid,
            resource#>>'{codeSystem,system}' as system,
            null::text as parent_code,
            jsonb_array_elements(resource#>'{compose,include}') as include
          FROM valueset
          WHERE jsonb_typeof(resource#>'{compose,include}') IS NOT NULL
        ) _
    ) _
)
INSERT INTO _valueset_expansion (valueset_id, system, parent_code, code, display)
SELECT
  vid, system, parent_code, concept->>'code' as code, concept->>'display' as display
FROM concepts;

CREATE INDEX idx_valueset_expansion_ilike ON _valueset_expansion  USING GIN (name, display gin_trgm_ops);
CREATE INDEX idx_valueset_valuset_id ON _valueset_expansion (valueset_id);
