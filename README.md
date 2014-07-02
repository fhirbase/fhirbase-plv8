# FHIRBase

Open source relational storage for [FHIR](http://hl7.org/implement/standards/fhir/) targeting real production.

[![Build Status](https://travis-ci.org/fhirbase/fhirbase.png?branch=master)](https://travis-ci.org/fhirbase/fhirbase)

Powered by [Health Samurai](http://healthsamurai.github.io/)

Sponsored by:

![choice-hs.com](http://choice-hs.com/Images/Shared/Choice-HSLogo.png)

## Live Demo

Here is an [interactive demo](http://try-fhirplace.hospital-systems.com/fhirface/index.html),
which is build with [FHIRPlace](https://github.com/fhirbase/fhirplace/) & [FHIRFace](https://github.com/fhirbase/fhirface/) by-products.


## Motivation

While crafting Health IT systems you begin to understand a value of properly chosen domain model.
FHIR is an open source new generation lightweight standard for health data interoperability,
which (we hope) could be used as a foundationan for Health IT systems. FHIR is based on a concept of __resource__.

> FHIR® is a next generation standards framework created by HL7.
> FHIR combines the best features of HL7 Version 2,
> Version 3 and CDA® product lines while leveraging the latest
> web standards and applying a tight focus on implementability.

Also we learned that data is a heart of any information system,
and should be reliably managed. PostgreSQL is battle proved open source
database, which supports structured documents (jsonb), while preserving
ACID guaranties and richness of SQL query language.

> PostgreSQL is a powerful, open source object-relational database system.
> It has more than 15 years of active development and a proven architecture
> that has earned it a strong reputation for reliability, data integrity, and correctness.

Here is list of PostgreSQL features we use:

* [xml](http://www.postgresql.org/docs/9.4/static/functions-xml.html)
* [jsonb](http://www.postgresql.org/docs/9.4/static/functions-json.html)
* [inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)
* [materialized views](http://www.postgresql.org/docs/9.4/static/sql-altermaterializedview.html)
* [uuid](http://www.postgresql.org/docs/9.4/static/pgcrypto.html)

We actively collaborate with PostgreSQL lead developers to craft production ready
storage for FHIR.

TODO: about fhirb, VODKA and jsquery


> Why we are doing this inside database?

We decided to implement most of FHIR specification inside database for
scalability reason (all data operations is done efficiently in databse).

This approach also gives you possibility use FHIRBase from your prefered lang/platform (.NET, java, ruby, nodejs etc).
We implemented FHIR complaint server in clojure, with small amount of code - [FHIRPlace](https://github.com/fhirbase/fhirplace/).

And there is option to break FHIR specification abstraction (if required) and
go into database by generic SQL interface and complete your business task.


## Overview

We heavily use PostgreSQL [inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html) feature,
for polymorphic operations.

Here are base tables:

To store resource data:

* resource - for current resources
* resource_history - for resource historical versions
* tag - for tags
* tag_history - tags history

There are some "index" tables by one for each search parameter type and one for indexing all resource references,
which are populated in sync with resource data and  provide
fast FHIR search queries:

* search_string
* search_token
* search_date
* search_reference
* search_quantity
* references

For each resource type FHIRbase generate set of tables (which inherit from base tables).
This is done, to separate dataspaces for each resource, so they are not messed and
can guarantee performance proportional to amount of data for particular type of resource.

Note: Same trick is used by PostgreSQL for [partitioning](http://www.postgresql.org/docs/9.4/static/ddl-partitioning.html).


* "{{lower(ResourceType)}}" (...) INHERITS (resource)
* "{{lower(ResourceType)}}_history" (...) INHERITS (resource_history)
* "{{lower(ResourceType)}}_tag" (...) INHERITS (tag)
* "{{lower(ResourceType)}}_tag_history" (...) INHERITS tag_history

* "{{lower(ResourceType)}}_sort" (...)

* "{{lower(ResourceType)}}_search_string" (...)
* "{{lower(ResourceType)}}_search_token" (...)
* "{{lower(ResourceType)}}_search_date" (...)
* "{{lower(ResourceType)}}_search_reference" (...)
* "{{lower(ResourceType)}}_search_quantity" (...)
* "{{lower(ResourceType)}}_references" (...)

For more information [see source code](https://github.com/fhirbase/fhirbase/blob/master/dev/4_generation.sql#L51):



## Installation

Requirements:
* PostgreSQL 9.4 (http://www.postgresql.org/about/news/1522/)
* pgcrypto
* pg_trgm


You can build Postgresql from source  on debian/ubuntu
and create local user cluster with:


```
source local_cfg.sh && ./install-postgres
```

NOTE: you can tune configuration in local_cfg.sh.

You can install FHIRBase:

```
source local_cfg.sh
echo 'CREATE DATABASE mydb' | psql postgres
psql mydb < fhirplace--1.0.sql
```

TODO: test script to verify installation

## Usage

Most of FHIR complaint operations could be done with FHIRBase procedures,
which guaranties data integrity and do heavy job for you:

`insert_resource(resource jsonb, tags jsonb)`
insert resource and fill tag & index tables

`insert_resource(id uuid, resource jsonb, tags jsonb)`
overloaded version taking explicit id

`update_resource(id uuid, _rsrs jsonb, _tags jsonb)`
create new version of resource and move old version into resource_history table

`delete_resource(id uuid, res_type varchar)`
remove resource preserving all history versions

`search_bundle(_resource_type varchar, query jsonb)`
search resources of _resource_type by query object and return bundle json

`tags(), tags(_res_type varchar), tags(_res_type varchar, _id_ uuid), tags(_res_type varchar, _id_ uuid, _vid uuid)`
return tags for all resources, concrete type, concrete resource, concrete version of resource respectively

`affix_tags(_res_type varchar, _id_ uuid, _tags jsonb), affix_tags(_res_type varchar, _id_ uuid, _vid_ uuid, _tags jsonb)`
affix tags to current or concrete version

`remove_tags(_res_type varchar, _id_ uuid), remove_tags(_res_type varchar, _id_ uuid, _vid uuid)`
remove tags from current or concrete version of resource

`history_resource(_resource_type varchar, _id uuid)`
return history bundle for resource

## Contribution

* Star us on github
* Create an issue – for a bug report or enhancment
* Contribute to FHIRBase − see dev/README.md

## Development

Development detains see in [dev/README.md]()

## License

Copyright © 2014 health samurai

FHIRbase are released under the terms of the MIT license
