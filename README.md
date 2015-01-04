# FHIRBase

Open source relational storage for
[FHIR](http://hl7.org/implement/standards/fhir/) targeting real production.

[![Build Status](https://travis-ci.org/fhirbase/fhirbase.png?branch=master)](https://travis-ci.org/fhirbase/fhirbase)

Powered by [Health Samurai](http://healthsamurai.github.io/)

Sponsored by:

![choice-hs.com](http://choice-hs.com/Images/Shared/Choice-HSLogo.png)

## Live Demo

Here is an
[interactive demo](http://try-fhirplace.hospital-systems.com/fhirface/index.html),
which is build with
[FHIRPlace](https://github.com/fhirbase/fhirplace/) &
[FHIRFace](https://github.com/fhirbase/fhirface/) by-products.


## Motivation

While crafting Health IT systems wey understand a value of
properly chosen domain model.  FHIR is an open source new generation
lightweight standard for health data interoperability, which (we hope)
could be used as a foundationan for Health IT systems. FHIR is based
on a concept of __resource__.

> FHIR® is a next generation standards framework created by HL7.  FHIR
> combines the best features of HL7 Version 2, Version 3 and CDA®
> product lines while leveraging the latest web standards and applying
> a tight focus on implementability.

Also we learned that data is a heart of any information system, and
should be reliably managed. PostgreSQL is battle proved open source
database, which supports structured documents (jsonb), while
preserving ACID guaranties and richness of SQL query language.

> PostgreSQL is a powerful, open source object-relational database
> system.  It has more than 15 years of active development and a
> proven architecture that has earned it a strong reputation for
> reliability, data integrity, and correctness.

Here is list of PostgreSQL features we use:

* [xml](http://www.postgresql.org/docs/9.4/static/functions-xml.html)
* [jsonb](http://www.postgresql.org/docs/9.4/static/functions-json.html)
* [gin & gist](http://www.postgresql.org/docs/9.1/static/textsearch-indexes.html)
* [inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)
* [materialized views](http://www.postgresql.org/docs/9.4/static/sql-altermaterializedview.html)
* [uuid](http://www.postgresql.org/docs/9.4/static/pgcrypto.html)

We actively collaborate with PostgreSQL lead developers to craft
production ready storage for FHIR.


> Why we are doing this inside database?

We decided to implement most of FHIR specification inside database for
scalability reason (all data operations is done efficiently in databse).

This approach also gives you possibility use FHIRBase from your
prefered lang/platform (.NET, java, ruby, nodejs etc).
We implemented FHIR compliant server in clojure, with small amount of
code - [FHIRPlace](https://github.com/fhirbase/fhirplace/).

And there is option to break FHIR specification abstraction (if required) and
go into database by generic SQL interface and complete your business task.


## Features

* resources versioning
* CRUD operations on resources
* search operations
* optional indexing (to speedup search)
* history
* tags operations
* transaction

## Installation

Please follow
[FHIRPlace installation instructions](https://github.com/fhirbase/fhirplace#installation).

## Build

Requirements:
* PostgreSQL 9.4 (http://www.postgresql.org/about/news/1522/)
* pgcrypto
* pg_trgm
* btree_gin
* btree_gist

You can download postgresql 9.4 pre-release or build Postgresql from
source on debian/ubuntu and create local user cluster with:


```bash
source local_cfg.sh && ./install-postgres
```

NOTE: you can tune configuration in local_cfg.sh.

You can install FHIRBase:

```bash
source local_cfg.sh
echo 'CREATE DATABASE mydb' | psql postgres
psql mydb < fhirbase--1.0.sql
```

TODO: test script to verify installation


## Overview

To start quickly read [Getting Started Guide](https://github.com/fhirbase/fhirbase/blob/master/INTRO.md).

### STRUCTURE

We heavily use PostgreSQL
[inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)
feature, for polymorphic operations.

Here are base tables:

```sql
CREATE TABLE resource (
  version_id uuid,
  logical_id uuid,
  resource_type varchar,
  updated TIMESTAMP WITH TIME ZONE,
  published  TIMESTAMP WITH TIME ZONE,
  category jsonb,
  content jsonb
);

CREATE TABLE resource_history (
  version_id uuid,
  logical_id uuid,
  resource_type varchar,
  updated TIMESTAMP WITH TIME ZONE,
  published  TIMESTAMP WITH TIME ZONE,
  category jsonb,
  content jsonb
);
```

For each resource type FHIRbase generate two tables (which inherit
from base tables) - one for actual resources and one for history of resource.

This is done, to separate dataspaces for each
resource, so they are not messed up and can guarantee performance
proportional to amount of data for particular type of resource.

Note: Same trick is used by PostgreSQL for
[partitioning](http://www.postgresql.org/docs/9.4/static/ddl-partitioning.html).


For example for resource `Patient` we are generating tables:

```sql

CREATE TABLE "patient" (
  logical_id uuid PRIMARY KEY default gen_random_uuid(),
  version_id uuid UNIQUE default gen_random_uuid(),
  resource_type varchar DEFAULT '{{resource_type}}',
  updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  published TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  content jsonb NOT NULL,
  category jsonb
) INHERITS (resource);

CREATE TABLE "patient_history" (
  version_id uuid PRIMARY KEY,
  logical_id uuid NOT NULL,
  resource_type varchar DEFAULT '{{resource_type}}',
  updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  published TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  content jsonb NOT NULL,
  category jsonb
) INHERITS (resource_history);

```

For more information
[see source code](https://github.com/fhirbase/fhirbase/blob/master/dev/4_generation.sql#L51):

Most of FHIR complaint operations could be done with FHIRBase procedures,
which guaranties data integrity and do heavy job for you.
All procedures have first parameter `_cfg::jsonb` with configuration params, which required for url generation.
Now there is only one paramenter [base] (Service Root URL):
`{"base":"http://myserver"}`

### CRUD

CRUD operations on resource are represented as set of procedures:

#### FUNCTION fhir_create(_cfg jsonb, _type_ varchar, _resource_ jsonb, _tags_ jsonb)
Create a new resource with a server assigned id
Return bundle with newly entry;

Example:

```sql
SELECT fhir_create(
  '{"base":"fhir/end/point"}',
  'Patient',
  '{"resourceType":"Patient"}');
```

Result will be:

```json
Result:

{
  "id": "f27638e4-801b-4c5b-8d16-81912358f537",
  "entry":
   [{
     "id": "fhir/end/point/Patient/7043326d-f2eb-4d8b-81c5-13ace5a8a3d7",
     "link": [{"rel": "self", "href": "fhir/end/point/Patient/7043326d-f2eb-4d8b-81c5-13ace5a8a3d7/_history/7dd8adfc-0f3b-4b21-b44a-497dba699df9"}],
     "content": {
        "resourceType": "Patient"
     },
     "updated": "2014-12-19T22:54:16.926811+04:00",
     "category": [],
     "published": "2014-12-19T22:54:16.926811+04:00"
   }],
  "title": "Concrete resource by id 7043326d-f2eb-4d8b-81c5-13ace5a8a3d7",
  "updated": "2014-12-19T22:54:16.926811+04:00",
  "resourceType": "Bundle",
  "totalResults": 1
}
```

fhir_create has several forms:

*  fhir_create(_cfg jsonb, _resource jsonb)
*  fhir_create(_cfg jsonb, _type text, _id uuid, _resource jsonb, _tags jsonb)
*  fhir_create(_cfg jsonb, _type text, _resource jsonb)
*  fhir_create(_cfg jsonb, _type text, _resource jsonb, _tags jsonb)

You can skip _type parameter (it will be taken from resourceType attribute of resource).

Also you can pass tags as jsonb array: ```'[{"label":???, "system":???, "value":???}]'::jsonb```

#### FUNCTION fhir_read(_cfg jsonb, _type_ varchar, _id_ uuid)

Read the current state of the resource by logicalId (TODO: or by reference/url)
Return bundle with only one entry for uniformity;

```SQL

SELECT fhir_read('{"base":"fhir/end/point"}', 'Patient', uuid);

-- or you can search resource by id with ordinary SELECT

SELECT * FROM patient WHERE logical_id = 'uuid'

```

#### FUNCTION fhir_vread(_cfg jsonb, _type_ varchar, _id_ uuid, _vid_ uuid)

Read specific version of resource with _type_
Returns bundle with one entry;

#### FUNCTION fhir_update(_cfg jsonb, _type_ varchar, _id_ uuid, _vid_ uuid, _resource_ jsonb, _tags_ jsonb)
Update resource, creating new version
Returns bundle with one entry;

#### FUNCTION fhir_delete(_cfg jsonb, _type_ varchar, _id_ uuid)
DELETE resource by its id AND return deleted version
Return bundle with one deleted version entry ;

#### FUNCTION fhir_history(_cfg jsonb, _type_ varchar, _id_ uuid, _params_ jsonb)
Retrieve the changes history for a particular resource with logical id (_id_)
Return bundle with entries representing versions;


### SEARCH

#### FUNCTION fhir_search(_cfg jsonb, _type_ varchar, _params_ jsonb)

Search in resources with _type_ by _params_
Returns bundle with entries;


Helpful functions:

* search('Patient', 'name=smith') -- returns rows from resoure table
* build_search_query('Patient', 'name=smith') -- shows generated search sql
* analyze_search('Patient', 'name=smith') -- shows execution plan for search query

### INDEXING

Indexes are optional.

Index for specific search parameter could be created
using `index_search_param()` function:

```sql
SELECT index_search_param('Patient', 'name');
-- Time: 96168.725 ms

SELECT count(*) FROM patient;
--  count
---------
--  2262107
-- (1 row)

SELECT content->'name'
FROM search('Patient', 'name=john');
-- Time with index: 20.859 ms
-- Time without index: 1186.767 ms

SELECT content->'name'
FROM search('Patient', 'name=nonexisting');
-- Time with index: 20.01 ms
-- Time without index (i.e. full scan): 74429.122 ms

SELECT fhir_search('{}'::jsonb, 'Patient', 'name=john');
-- Time: 35.785 ms

-- But they are not for free

SELECT admin_disk_usage_top(10);

-- public.patient,                      "454 MB"
-- public.patient_name_name_string_idx, "140 MB"
```

You can drop indexes:

```sql
SELECT drop_index_search_param('Patient','name');
SELECT drop_resource_indexes('Patient');
SELECT drop_all_resource_indexes();
```

### TAGS

### OTHER

#### FUNCTION fhir_conformance(_cfg jsonb)
Returns conformance resource jsonb;


## Benchmarks


## Contribution

* Star us on GitHub
* If you encountered a bug, please [make an Issue](https://github.com/fhirbase/fhirplace/issues/new)
* Contribute to FHIRBase − see [dev/README.md](https://github.com/fhirbase/fhirbase/blob/master/dev/README.md)

## Development

See development details in [dev/README.md](https://github.com/fhirbase/fhirbase/blob/master/dev/README.md)

## License

Copyright © 2014 health samurai.

FHIRbase is released under the terms of the MIT License.
