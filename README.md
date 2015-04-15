# FHIRbase

![fhirbase](https://avatars3.githubusercontent.com/u/6482975?v=3&s=400)

FHIRbase is an open source relational storage for
[FHIR](http://hl7.org/implement/standards/fhir/) targeting real production.

[![Build Status](https://travis-ci.org/fhirbase/fhirbase.png?branch=master)](https://travis-ci.org/fhirbase/fhirbase)

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/fhirbase/fhirbase?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

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

* [jsonb](http://www.postgresql.org/docs/9.4/static/functions-json.html)
* [gin & gist](http://www.postgresql.org/docs/9.1/static/textsearch-indexes.html)
* [inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)

We actively collaborate with PostgreSQL lead developers to craft
production ready storage for FHIR.

> Why are we doing this inside a database?

We decided to implement most of FHIR specification inside a database for
scalability reason (all data operations are done efficiently in a database).

This approach also gives you a possibility to use FHIRbase from your
preferred lang/platform (.NET, java, ruby, nodejs etc).
We have implemented FHIR compliant server in clojure with small amount of
code - [FHIRPlace](https://github.com/fhirbase/fhirplace/).

And there is an option to break FHIR specification abstraction (if required) and
go into the database by generic SQL interface and complete your business task.


## Features

FHIRbase implements 80% of FHIR specification inside the database as
procedures:

* meta-data resource storage (StructureDefinition, ValueSet, SearchParameter, etc)
* CRUD on resources with history
* search operations with indexing
* transactions

## Documentation

* [Installation Guide](docs/installation.md)
* [Overview](docs/overview.md)
* [Development](docs/development.md)
* [Benchmarks](docs/benchmarks.md)

## Roadmap

* resource validation
* referential integrity
* terminology
* guides for java, .NET, python, ruby, js

## Contribution

* Star us on GitHub
* If you encountered a bug, please [make an Issue](https://github.com/fhirbase/fhirplace/issues/new)
* Contribute to FHIRbase − see [dev/README.md](https://github.com/fhirbase/fhirbase/blob/master/dev/README.md)

## Thxs

Powered by [Health Samurai](http://health-samurai.io/)

Sponsored by: ![choice-hs.com](http://choice-hs.com/Images/Shared/Choice-HSLogo.png)

## License

Copyright © 2014 health samurai.

FHIRbase is released under the terms of the MIT License.
