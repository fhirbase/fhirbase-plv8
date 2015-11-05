# fhirbase-plv8

[![Build Status](https://travis-ci.org/fhirbase/fhirbase-plv8.svg)](https://travis-ci.org/fhirbase/fhirbase-plv8)

This is new version of fhirbase, with support of DSTU-2 and planned support many advanced features:

*  Extended query syntax
*  Terminologies
*  Profile validation 
*  References validateion
*  ValueSet validateion


## Motivation

While crafting Health IT systems we understand an importance of a
properly chosen domain model. FHIR is an open source new generation
lightweight standard for health data interoperability, which (we hope)
could be used as a foundation for Health IT systems. FHIR is based
on a concept of __resource__.

> FHIR® is a next generation standards framework created by HL7.  FHIR
> combines the best features of HL7 Version 2, Version 3 and CDA®
> product lines while leveraging the latest web standards and applying
> a tight focus on implementability.

Also we learned that data is a heart of any information system, and
should be reliably managed. PostgreSQL is a battle proved open source
database which supports structured documents (jsonb) while
preserving ACID guaranties and richness of SQL query language.

> PostgreSQL is a powerful, open source object-relational database
> system.  It has more than 15 years of active development and a
> proven architecture that has earned it a strong reputation for
> reliability, data integrity, and correctness.

Here is the list of PostgreSQL features that we use:

* [plv8](http://pgxn.org/dist/plv8/doc/plv8.html)
* [jsonb](http://www.postgresql.org/docs/9.4/static/functions-json.html)
* [gin & gist](http://www.postgresql.org/docs/9.1/static/textsearch-indexes.html)
* [inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)


## Installation

To install fhirbase you need postgresql-9.4 and plv8 extension.


```sh
sudo apt-get install postgresql-contrib-9.4 postgresql-9.4-plv8  -qq -y
psql -c "CREATE USER user WITH PASSWORD 'password'"
psql -c 'CREATE DATABASE fhirbase;' -U user
psql -c '\dt' -U postgres
export DATABASE_URL=postgres://user:password@localhost:5432/fhirbase

wget https://github.com/fhirbase/fhirbase-plv8/releases/download/v0.0.1-alpha/fhirbase-0.0.1.sql.zip
unzip fhirbase-0.0.1.sql.zip

cat fhirbase-0.0.1.sql | psql fhirbase
```


## Development Installation

Development installation requires node 0.12 and npm,
which could be installed by [nvm](https://github.com/creationix/nvm):

```sh
# install node < 0.12 by nvm for example
sudo apt-get install postgresql-contrib-9.4 postgresql-9.4-plv8  -qq -y

git clone https://github.com/fhirbase/fhirbase-plv8
cd fhirbase-plv8
git submodule init && git submodule update

npm install && cd plpl && npm install
npm install -g mocha && npm install -g coffee-script

psql -c "CREATE USER fb WITH PASSWORD 'fb'"
psql -c 'ALTER ROLE fb WITH SUPERUSER'
psql -c 'CREATE DATABASE fhirbase;' -U postgres
psql -c '\dt' -U postgres

export DATABASE_URL=postgres://fb:fb@localhost:5432/fhirbase

plpl/bin/plpl migrate
plpl/bin/plpl reload
npm run test
```

## Usage

To make fhirbase-plv8 work
you have to just after opening connection to postgresql
you have to issue following command (read more [here](http://pgxn.org/dist/plv8/doc/plv8.html#Start-up.procedure)):


```sql
SET plv8.start_proc = 'plv8_init'
```


```sql

SET plv8.start_proc = 'plv8_init'

-- work with storage

SELECT create_storage('{"resourceType": "Patient"}'); // create tables for resource & history
SELECT drop_storage('{"resourceType": "Patient"}'); // drop tables
SELECT truncate_storage('{"resourceType": "Patient"}'); // delete all resources of specified type

-- CRUD

SELECT create_resource('{"resourceType": "Patient", id: "smith", "name": [{"given": ["Smith"]}]});
SELECT read_resource('{"resourceType": "Patient", id: "smith"});
SELECT vread_resource('{"resourceType": "Patient", versionId: "????"});
SELECT resource_history('{"resourceType": "Patient", id: "smith"});
SELECT resource_type('{"resourceType": "Patient"});
SELECT update_resource('{"resourceType": "Patient", id: "smith", "name": [{"given": ["John"], "family": ["Smith"]}]});

SELECT search('{"resourceType": "Patient", queryString: "name=smith"});

SELECT index_parameter('{"resourceType": "Patient", name: "name"});
SELECT unindex_parameter('{"resourceType": "Patient", name: "name"});

SELECT search_sql('{"resourceType": "Patient", queryString: "name=smith"}); 
-- see generated SQL

SELECT explain_search('{"resourceType": "Patient", queryString: "name=smith"});
-- see execution plan

SELECT delete_resource('{"resourceType": "Patient", id: "smith"});

```

## Contribution

* Star us on GitHub
* If you encountered a bug, please [make an Issue](https://github.com/fhirbase/fhirbase-plv8/issues/new)
* Contribute to fhirbase

## License

Copyright © 2014 health samurai.

fhirbase is released under the terms of the MIT License.
