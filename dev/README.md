# Overview

Fhirbase is generated from profiles-resources.xml & fhir-base.xsd.

##  Install postgresql 9.4

Postgresql 9.4 with support jsonb required.

You can download official pre-release http://www.postgresql.org/about/news/1522/
or build postgresql from sources.

Installation for debian/ubuntu linux could be done as:

```
git clone https://github.com/fhirbase/fhirbase.git
cd fhirbase
source ./local_cfg.sh && ./install-postgres
```

This will install postgresql in `$SOURCE_DIR` (could be configured in local_cfg; by default [project]/tmp)
and add $BUILD_DIR/bin to path.


## Install fhirbase

For development `cd dev` and use `./runme` script.

```
./runme install [dbname] # setup fhirbase in [dbname]
./runme integrate # setup fhirbase into $DB (fhirb by default) and run tests
./runme test # run tests on installed database
```

## Layout

```
runme #  run util documented below
01_fns.sql # helper functins
01_lexicograph.sql # number=>string convertion for lexicographic sorting algorythm
02_datatypes.sql # fill meta table with datatypes info from fhir-base.xsd
03_resources.sql # load meta about resources
04_generation.sql # generate schema
05_index_number.sql # indexing & searching number
05_index_reference.sql  # indexing & searching references
05_index_string.sql # indexing & searching strings
06_index_date.sql # datas
06_index_quantity.sql # quantity
06_index_token.sql # token
08_insert_resource.sql # create, update & delete for resource with indexing
08_research.sql # start search refactoring
08_search_params.sql # utils to parse search url string
09_search.sql # search functions
10_api.sql # api facade
10_conformance.sql # generate conformance & profile from metainfo
10_tags.sql # working with tags
11_ucum.sql # TODO: ucum data for quantity manipulation
```
