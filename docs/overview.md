## FHIRbase: FHIR persistence in PostgreSQL

FHIR is a specification of semantic resources and API for working with healthcare data.
Please address the [official specification](http://hl7-fhir.github.io/) for more details.

To implement FHIR server we have to persist & query data in an application internal
format or in FHIR format. This article describes how to store FHIR resources
in a relational database (PostgreSQL), and open source FHIR
storage implementation - [FHIRbase](https://github.com/fhirbase/fhirbase).


## Overview

*FHIRbase* is built on top of PostgreSQL and requires its version higher than 9.4
(i.e. [jsonb](http://www.postgresql.org/docs/9.4/static/datatype-json.html) support).

FHIR describes ~100 [resources](http://hl7-fhir.github.io/resourcelist.html)
as base StructureDefinitions which by themselves are resources in FHIR terms.

To setup FHIRbase use [Installation Guide](installation.md).

FHIRbase stores each resource in two tables - one for current version
and second for previous versions of the resource. Following a convention, tables are named
in a lower case after resource types: Patient => patient, StructureDefinition => structuredefinition.

For example *Patient* resources are stored
in *patient* and *patient_history* tables:

```psql
fhirbase=# \d patient
                       Table "public.patient"
    Column     |           Type           |        Modifiers
---------------+--------------------------+-------------------------
 version_id    | text                     |
 logical_id    | text                     | not null
 resource_type | text                     | default 'Patient'::text
 updated       | timestamp with time zone | not null default now()
 published     | timestamp with time zone | not null default now()
 category      | jsonb                    |
 content       | jsonb                    | not null
Inherits: resource

fhirbase=# \d patient_history

                   Table "public.patient_history"
    Column     |           Type           |        Modifiers
---------------+--------------------------+-------------------------
 version_id    | text                     | not null
 logical_id    | text                     |
 resource_type | text                     | default 'Patient'::text
 updated       | timestamp with time zone | not null default now()
 published     | timestamp with time zone | not null default now()
 category      | jsonb                    |
 content       | jsonb                    | not null
Inherits: resource_history
```

All resource tables have similar structure and are inherited from *resource* table,
to allow cross-table queries (for more information see [PostgreSQL inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)).

Minimal installation of FHIRbase consists of only a
few tables for "meta" resources:

* StructureDefinition
* OperationDefinition
* SearchParameter
* ValueSet
* ConceptMap

These tables are populated with resources provided by FHIR distribution.

Most of API for FHIRbase is represented as functions in *fhir* schema,
other schemas are used as code library modules.

First helpful function is `fhir.generate_tables(resources text[])` which generates tables
for specific resources passed as array.
For example to generate tables for patient, organization and encounter:

```sql
psql fhirbase

fhirbase=# select fhir.generate_tables('{Patient, Organization, Encounter}');

--  generate_tables
-----------------
--  3
-- (1 row)
```

If you call generate_tables() without any parameters,
then tables for all resources described in StructureDefinition
will be generated:

```sql

fhirbase=# select fhir.generate_tables();
-- generate_tables
-----------------
-- 93
--(1 row)
```

When concrete resource type tables are generated,
column *installed* for this resource is set to true in the profile table.

```sql
SELECT logical_id, installed from structuredefinition
WHERE logical_id = 'Patient'

--  logical_id | installed
----------------------------
--  Patient    | true
```

Functions representing public API of FHIRbase are all located in the FHIR schema.
The first group of functions implements CRUD operations on resources:

* create(resource json)
* read(resource_type, logical_id)
* update(resource json)
* vread(resource_type, version_id)
* delete(resource_type, logical_id)
* history(resource_type, logical_id)
* is_exists(resource_type, logical_id)
* is_deleted(resource_type, logical_id)


```sql

SELECT fhir.create('{"resourceType":"Patient", "name": [{"given": ["John"]}]}')
-- {
--  "id": "c6f20b3a...",
--  "meta": {
--    "versionId": "c6f20b3a...",
--    "lastUpdated": "2015-03-05T15:53:47.213016+00:00"
--  },
--  "name": [{"given": ["John"]}],
--  "resourceType": "Patient"
-- }
--(1 row)

-- create - insert new row into patient table
SELECT resource_type, logical_id, version_id,* from patient;

-- resource_type |  logical_id  |  version_id | content
---------------+---------------------------------------------------
-- Patient       | c6f20b3ab... | c6f20b....  | {"resourceType".....}
--(1 row)



SELECT fhir.read('Patient', 'c6f20b3a...');
-- {
--  "id": "c6f20b3a...",
--  "meta": {
--    "versionId": "c6f20b3a...",
--    "lastUpdated": "2015-03-05T15:53:47.213016+00:00"
--  },
--  "name": [{"given": ["John"]}],
--  "resourceType": "Patient"
-- }
--(1 row)

SELECT fhir.update(
   jsonbext.merge(
     fhir.read('Patient', 'c6f20b3a...'),
     '{"name":[{"given":"Bruno"}]}'
   )
);
-- returns update version

SELECT count() FROM patient; => 1
SELECT count() FROM patient_history; => 1

-- read previous version of resource
SELECT fhir.vread('Patient', /*old_version_id*/ 'c6f20b3a...');


SELECT fhir.history('Patient', 'c6f20b3a...');

-- {
--     "type": "history",
--     "entry": [{
--         "resource": {
--             "id": "c6f20b3a...",
--             "meta": {
--                 "versionId": "a11dba...",
--                 "lastUpdated": "2015-03-05T16:00:12.484542+00:00"
--             },
--             "name": [{
--                 "given": "Bruno"
--             }],
--             "resourceType": "Patient"
--         }
--     }, {
--         "resource": {
--             "id": "c6f20b3a...",
--             "meta": {
--                 "versionId": "c6f20b3a...",
--                 "lastUpdated": "2015-03-05T15:53:47.213016+00:00"
--             },
--             "name": [{
--                 "given": ["John"]
--             }],
--             "resourceType": "Patient"
--         }
--     }],
--     "resourceType": "Bundle"
-- }

SELECT fhir.is_exists('Patient', 'c6f20b3a...'); => true
SELECT fhir.is_deleted('Patient', 'c6f20b3a...'); => false

SELECT fhir.delete('Patient', 'c6f20b3a...');
-- return last version

SELECT fhir.is_exists('Patient', 'c6f20b3a...'); => false
SELECT fhir.is_deleted('Patient', 'c6f20b3a...'); => true
```
When resource is created, *logical_id* and *version_id* are generated as uuids.
On each update resource content is updated in the *patient* table, and old version of the resource is copied
into the *patient_history* table.

## Transaction


## Search & Indexing

Next part of API is a search API.
Folowing functions will help you to search resources in FHIRbase:

* fhir.search(resourceType, searchString) returns a bundle
* fhir._search(resourceType, searchString) returns a relation
* fhir.explain_search(resourceType, searchString) shows an execution plan for search
* fhir.search_sql(resourceType, searchString) shows the original sql query underlying the search

```sql

select fhir.search('Patient', 'given=john')
-- returns bundle
-- {"type": "search", "entry": [...]}

-- return search as relatio
select * from fhir._search('Patient', 'name=david&count=10');

-- version_id | logical_id     | resource_type
------------+----------------------------------
--            | "a8bec52c-..." | Patient
--            | "fad90884-..." | Patient
--            | "895fdb15-..." | Patient


-- expect generated by search sql
select fhir.search_sql('Patient', 'given=david&count=10');

-- SELECT * FROM patient
-- WHERE (index_fns.index_as_string(patient.content, '{given}') ilike '%david%')
-- LIMIT 100
-- OFFSET 0

-- explain query execution plan
select fhir.explain_search('Patient', 'given=david&count=10');

-- Limit  (cost=0.00..19719.37 rows=100 width=461) (actual time=6.012..7198.325 rows=100 loops=1)
--   ->  Seq Scan on patient  (cost=0.00..81441.00 rows=413 width=461) (actual time=6.010..7198.290 rows=100 loops=1)
--         Filter: (index_fns.index_as_string(content, '{name,given}'::text[]) ~~* '%david%'::text)
--         Rows Removed by Filter: 139409
-- Planning time: 0.311 ms
-- Execution time: 7198.355 ms
```

Search works without indexing but search query would be slow
on any reasonable amount of data.
So FHIRbase has a group of indexing functions:

* index_search_param(resourceType, searchParam)
* drop_index_search_param(resourceType, searchParam)
* index_resource(resourceType)
* drop_resource_indexes(resourceType)
* index_all_resources()
* drop_all_resource_indexes()

Indexes are not for free - they eat space and slow inserts and updates.
That is why indexes are optional and completely under you control in FHIRbase.

Most important function is `fhir.index_search_param` which
accepts resourceType as a first parameter, and name of search parameter to index.

```sql

select count(*) from patient; --=> 258000

-- search without index
select fhir.search('Patient', 'given=david&count=10');
-- Time: 7332.451 ms

-- index search param
SELECT fhir.index_search_param('Patient','name');
--- Time: 15669.056 ms

-- index cost
select fhir.admin_disk_usage_top(10);
-- [
--  {"size": "107 MB", "relname": "public.patient"},
--  {"size": "19 MB", "relname": "public.patient_name_name_string_idx"},
--  ...
-- ]

-- search with index
select fhir.search('Patient', 'name=david&count=10');
-- Time: 26.910 ms

-- explain search

select fhir.explain_search('Patient', 'name=david&count=10');

------------------------------------------------------------------------------------------------------------------------------------------------
-- Limit  (cost=43.45..412.96 rows=100 width=461) (actual time=0.906..6.871 rows=100 loops=1)
--   ->  Bitmap Heap Scan on patient  (cost=43.45..1569.53 rows=413 width=461) (actual time=0.905..6.859 rows=100 loops=1)
--         Recheck Cond: (index_fns.index_as_string(content, '{name}'::text[]) ~~* '%david%'::text)
--         Heap Blocks: exact=100
--         ->  Bitmap Index Scan on patient_name_name_string_idx  (cost=0.00..43.35 rows=413 width=0) (actual time=0.205..0.205 rows=390 loops=1)
--               Index Cond: (index_fns.index_as_string(content, '{name}'::text[]) ~~* '%david%'::text)
-- Planning time: 0.449 ms
-- Execution time: 6.946 ms
```

### Performance Tests

### Road Map



