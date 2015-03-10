# fhirbase

Production-ready open source relational storage for
[FHIR](http://hl7.org/implement/standards/fhir/) targeting real production.

[![Build Status](https://travis-ci.org/fhirbase/fhirbase.png?branch=master)](https://travis-ci.org/fhirbase/fhirbase)

## Motivation

While crafting Health IT systems we understand a value of
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

fhirbase implements 80% of FHIR specification inside database as
procedures:

* meta-data resources storage (StructureDefinition, ValueSet, SearchParameter etc)
* CRUD on resources with history
* search operations with indexing
* transactions

## Documentation

* [Installation Guide](docs/installation.md)
* [Overview](docs/overview.md)
* [Development](docs/development.md)
* [Benchmarks](docs/benchmarks.md)
* TODO: guides
   * python
   * ruby
   * node
   * java
   * .NET

## Roadmap

* resources validation
* referential integrity
* terminology

## Contribution

* Star us on GitHub
* If you encountered a bug, please [make an Issue](https://github.com/fhirbase/fhirplace/issues/new)
* Contribute to fhirbase − see [dev/README.md](https://github.com/fhirbase/fhirbase/blob/master/dev/README.md)

## Thxs

Powered by [Health Samurai](http://healthsamurai.github.io/)

Sponsored by: ![choice-hs.com](http://choice-hs.com/Images/Shared/Choice-HSLogo.png)

## License

Copyright © 2014 health samurai.

fhirbase is released under the terms of the MIT License.
