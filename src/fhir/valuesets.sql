-- #import ./generate.sql
-- #import ./crud.sql

drop table if exists valueset, conceptmap;
drop table if exists valueset_history, conceptmap_history;

update profile set installed = false
  where name in ('ValueSet', 'ConceptMap');

func! load_bundle(bundle jsonb) returns bigint
  SELECT
    count(crud.create('{}'::jsonb,
        jsonbext.merge(
          x#>'{resource}',
          '{"text":{"status":"generated","div":"<div>too costy</div>"}}'::jsonb
        )))
    FROM jsonb_array_elements(bundle#>'{entry}') x;

SELECT generate.generate_tables('{ValueSet, ConceptMap}');
--

\set valuesets `cat fhir/valuesets.json`
SELECT 'valuesets ' || this.load_bundle(:'valuesets');

\set valuesets `cat fhir/v2-tables.json`
SELECT 'v2-tables ' || this.load_bundle(:'valuesets');

\set valuesets `cat fhir/v3-codesystems.json`
SELECT 'v3-codesystems ' || this.load_bundle(:'valuesets');

\set valuesets `cat fhir/conceptmaps.json`
SELECT 'conceptmaps ' || this.load_bundle(:'valuesets');
