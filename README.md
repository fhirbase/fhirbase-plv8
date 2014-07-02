# FHIRBase

Open source relational storage for [FHIR](http://hl7.org/implement/standards/fhir/).

[![Build Status](https://travis-ci.org/fhirbase/fhirbase.png?branch=master)](https://travis-ci.org/fhirbase/fhirbase)

Powered by [Health Samurai](http://healthsamurai.github.io/)

Sponsored by:

![choice-hs.com](http://choice-hs.com/Images/Shared/Choice-HSLogo.png)

## Live Demo

Here is an [interactive demo](http://try-fhirplace.hospital-systems.com/fhirface/index.html).


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

## Overview

For each resource type FHIRbase create set of tables
[see source code](https://github.com/fhirbase/fhirbase/blob/master/dev/4_generation.sql#L51):

* <RESOURCE-TYPE>             (patient)
* <RESOURCE-TYPE>_tag         (patient_tag)

* <RESOURCE-TYPE>_history     (patient_history)
* <RESOURCE-TYPE>_tag_history (patient_tag_history)



## Installation

## Usage

## Contribution

* Star us on github
* Create an issue – for a bug report or enhancment
* Contribute to FHIRBase − see dev/README.md

## Roadmap

* Extensions

## License

Copyright © 2014 health samurai

FHIRbase are released under the terms of the MIT license
