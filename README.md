# fhirbase-plv8

This is *rewrite* of fhirbase, i.e. fhirbase-2.


# Why?

There are couple of reasons to rewrite and redesign fhirbase:

### Switch primary language to JavaScript

fhirbase was written mostly in sql & pgpsql, but development using
this langs is quite cryptic and there are no so much developers ready to contribute.

We hope, that by switching essential part of code base to more pop-language like JavaScript (Coffee script)
make threshold lower and bring more developers to fhirbase.

Most utils around fhirbase like tests, migrations, maintenance tasks could be written using JS (node) stack
and unify development.

Another reason for JS: that we could develop pure js library for FHIR Resources Profile validation and reuse
it in database, in browser and on the servers side (node or embeded js).

### Separation of concerns

Redesign fhirbase in a way, that we could separate
fhirbase meta-layer (basic CRUD, search, tables, history),
which do not require FHIR meta-information and then build FHIR operations
on top of it.

This is good, because  FHIR meta data is changing actively, so we should
adopt this into evalulation workflow, i.e. core of fhirbase should work without concrete FHIR
metadata making as less asumptions on it as possible.

This approach gives users possibility to extend fhirbase for specific needs without
strictly coupling to FHIR - for example create FHIR-like resources, which never be part of FHIR,
but with almost the same operations and structure.


## Preview

Architecture sketch:

LAYER 0: utils (as separate standalone module)
-----------------------------------------

* migrations utils
* js modules to plv8
* test utils
* performance tests

LAYER 1: fhirbase core
-----------------------------------------

* generate tables for resource & history
* basic CRUD:  create, update, read, delete, history
* register postgresql functions as operations
* basic interceptors for operations: for example register validation interceptor for create Patient
* basic search & indexing: search, where query has enough metadata to build SQL
  for example: search('Patient', '{params: [{path: "name.#.given", type: 'text', element: {type: "String", array: true}]}')
* referential consistency checks

LAYER 1: FHIR impl
-----------------------------------------

* storage for FHIR metadata:  structure def, operations, search params, valuesets
* implement FHIR crud & search using metadata on top of basic crud
* resources validation & ref. consistency checks
* terminology implementation
* transaction impl


EXTENSIONS
-----------------------------------------

* terminology extensions: LOINC, SNOMED, RxNORM etc
* maintains utils
