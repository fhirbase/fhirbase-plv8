# fhirbase

Open source relational storage for
[FHIR](http://hl7.org/implement/standards/fhir/) targeting real production.

[![Build Status](https://travis-ci.org/fhirbase/fhirbase.png?branch=master)](https://travis-ci.org/fhirbase/fhirbase)


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

* [jsonb](http://www.postgresql.org/docs/9.4/static/functions-json.html)
* [gin & gist](http://www.postgresql.org/docs/9.1/static/textsearch-indexes.html)
* [inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)

We actively collaborate with PostgreSQL lead developers to craft
production ready storage for FHIR.

> Why we are doing this inside database?

We decided to implement most of FHIR specification inside database for
scalability reason (all data operations is done efficiently in database).

This approach also gives you possibility use fhirbase from your
prefered lang/platform (.NET, java, ruby, nodejs etc).
We implemented FHIR compliant server in clojure, with small amount of
code - [FHIRPlace](https://github.com/fhirbase/fhirplace/).

And there is option to break FHIR specification abstraction (if required) and
go into database by generic SQL interface and complete your business task.


## Features

* CRUD on resources with history
* search operations with optional indexing (to speedup search)
* transaction
* TODO: meta operations

## Install on linux

Requirements:
* PostgreSQL 9.4
* pgcrypto
* pg_trgm
* btree_gin
* btree_gist

You can install fhirbase:

```bash
sudo apt-get install postgresql-9.4 curl
# create local user for ident auth
sudo su postgres -c 'createuser -s <you-local-user>'
# create empty database
psql -d postgres -c 'create database test'
# install last version of fhirbase
curl https://raw.githubusercontent.com/fhirbase/fhirbase-build/master/fhirbase.sql | psql -d test
# generate tables
psql -d test -c 'SELECT fhir.generate_tables()'

psql
#> \dt
```

Here is asci cast for simplest installation - [https://asciinema.org/a/17236].

## Development installation

For development environment:

```bash
sudo apt-get install -qqy postgresql-9.4 curl python
sudo su postgres -c 'createuser -s <you-local-user>'
export PGUSER=<you-local-user>
export DB=test

git clone https://github.com/fhirbase/fhirbase
cd fhirbase
./runme integrate
```

### Install with docker

Fhirbase could be installed using [docker](https://www.docker.com/)

```bash
#run database container
docker run --name=fhirbase -d fhirbase/fhirbase-build

docker inspect fhirbase
# read ip of started container

docker run --rm -i -t fhirbase/fhirbase-build psql -h <container-ip> -U fhirbase -p 5432
```

There are two images on dockerhub:
 * [fhirbase](https://registry.hub.docker.com/u/fhirbase/fhirbase) - auto-build
 * [fhirbase-build](https://registry.hub.docker.com/u/fhirbase/fhirbase-build) - manual build (more robust)

You could build image by yourself:

```
git clone https://github.com/fhirbase/fhirbase/
cd fhirbase
docker build -t fhirbase:latest .
#run database container
docker run --name=fhirbase -d fhirbase

docker inspect fhirbase
# read ip of started container

docker run --rm -i -t fhirbase psql -h <container-ip> -U fhirbase -p 5432
```

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

Most of FHIR complaint operations could be done with fhirbase procedures,
which guaranties data integrity and do heavy job for you.

###  Examples

TODO: more API documentation

```sql
SELECT fhir.generate_tables('{Patient}');
SELECT fhir.index_search_param('Patient','name');
SELECT fhir.index_resource('Patient');

SELECT fhir.create('{"resourceType":"Patient", "id":"myid", "name": [{"text":"Ivan"}]}'::jsonb);
SELECT fhir.read('Patient', 'myid');
SELECT fhir.update(updatedJsonWithId);

SELECT fhir.is_exists('Patient', 'myid');
SELECT fhir.is_deleted('Patient', 'myid');

SELECT fhir.delete('Patient', 'myid');
SELECT fhir.search('Patient', 'name=Ivan');
```

See full list of API functions in [src/fhir.sql].

## Benchmarks

### Heroku

Register on [Heroku][]

[Heroku]: https://heroku.com

Then login and create app

```sh
heroku login
heroku apps:create your-app-name
```

Then create PostgreSQL 9.4 database

```sh
heroku addons:add heroku-postgresql --app your-app-name --version=9.4
```

Then restore fhirbase dump and generate tables

```sh
curl https://raw.githubusercontent.com/fhirbase/fhirbase-build/master/fhirbase.sql \
  | pg:psql --app your-app-name YOUR_DB_NAME
pg:psql --app your-app-name YOUR_DB_NAME --command 'SELECT fhir.generate_tables()'
```

## Contribution

* Star us on GitHub
* If you encountered a bug, please [make an Issue](https://github.com/fhirbase/fhirplace/issues/new)
* Contribute to fhirbase − see [dev/README.md](https://github.com/fhirbase/fhirbase/blob/master/dev/README.md)

## Thxs

Powered by [Health Samurai](http://healthsamurai.github.io/)

Sponsored by: ![choice-hs.com](http://choice-hs.com/Images/Shared/Choice-HSLogo.png)

## Development

See development details in [dev/README.md](https://github.com/fhirbase/fhirbase/blob/master/dev/README.md)

## License

Copyright © 2014 health samurai.

fhirbase is released under the terms of the MIT License.
