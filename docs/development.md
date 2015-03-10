## Development Guide

Quick installation on ubuntu:

```bash
sudo apt-get install -qqy postgresql-9.4 postgresql-contrib-9.4 curl python
sudo su postgres -c 'createuser -s <you-local-user>'
export PGUSER=<you-local-user>
export DB=test

git clone https://github.com/fhirbase/fhirbase
cd fhirbase
./runme integrate
```

### Project structure

* docs/   - all documentation goes here
* fhir/   - core profiles from FHIR distrib
* perf/   - benchmarks stuf
* schema/ - schema migrations
* src/    - functions source code
* test/   - tests
* ql/     - runme & preprocessor code written in python
* runme*  - utils to work with fhirbase

Code is split into two categories -
schema changing code (migrations in `schema/` directory) and reloadable functions (in `src/`).

To reduce sql boilerplate and modularize application
we use simple SQL preprocessor written in python (in `ql/` directory).

### runme

All tasks for fhirbase could be done using `runme` script in form
```bash
env DB=test ./runme <command> <args>
```

Here is the list of subcomands:

* migrate - migrate DB to latest schema version
* test - run tests on DB
* integrate - drop & create DB, migrate and reload code, then run tests
* load <files-glob> - load module into database if changed
* reload <files-glob> - force load module into database
* compile <file-glob> - preprocess file and send it to STDOUT
* build - integrate database and create dump for distribution

### Pre-processor & Dependency management

PostgreSQL has one-level namespaces - [schemas](http://www.postgresql.org/docs/9.4/static/ddl-schemas.html).
We use schemas to implement code modules, this allow create and reload modules as a whole.
Every file in `src/` is mapped to schema with same name as file.
For example functions defined in `src/fhir.sql` will be in *fhir* schema.

Having modules allows us introduce dependencies between modules.
They implemented as magic comments in source files and using loader (./runme).

For example you have created module a.sql with function `util`. Then you want to
create module b.sql, which depends on module `a`:

```sql
-- file src/b.sql
-- #import ./a.sql

...
  b.util()
...

```

Then you can load module b into databse:

```bash
./runme load src/a.sql
```

Loader read `#import` instructions and resolve dependencies recursively,
then load all modules in right order and write module status into special table `modules`.
Loader also calculate sha1 of module file
content and reload module only if hash changed (caching).
If you run `load` command again without changes in files - it will do nothing.

To reduce sql boilerplate you can use some macro expansions in source files.

#### func and func!

you can write sql functions in python style,
ie body of function should be idented:

```sql
-- FILE: src/coll.sql
func _butlast(_ar_ anyarray) returns anyarray
  SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1]
```

Preprocessor will produce:

```sql
-- FILE: src/coll.sql
drop schema if exists coll cascade;
create schema coll;
CREATE OR REPLACE
function coll._butlast(_ar_ anyarray) RETURNS anyarray
LANGUAGE sql AS $$
  SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1] -- coll:3
$$ IMMUTABLE;

```

You can always inspect result of preprocessor by running `./runme compile src/file.sql`.

Here is list of macro expansions:

* func(args) returns type => sql IMMUTABLE function
* func!(args) returns type => sql function
* proc(args) returns type => pg/plsql IMMUTABLE function
* proc!(args) returns type => pg/plsql function
* this => replaced with name of current schema name

### Migrations

To allow update existing fhirbase installation to next version, we track schema changes
using migrations approach - all schema changes are in `schema/` directory and enumerated using
timestamps. When you run `/.runme migrate` all pending migrations will be applied.

### Tests

There are some preprocessor sugar for tests:

```sql
-- one-line test
select 1 => 1

---will be compiled into:

SELECT tests.expect('', 'test/<file>.sql:<line-number>',(select 1),(1));
```

Here is also multiline form (body should be idented):

```sql
expect "Comment"
  select 1
=> 1

-- compiled

SELECT tests.expect('Comment', 'test/<file>.sql:<line-number>',(select 1),(1));
```

To test for exeptions there is special syntax:

```sql
expect_raise 'does not exist'
  SELECT crud.delete('{}'::jsonb, 'Patient', 'nonexisting')

--- compiled

SELECT tests.expect_raise('does not exist', 'test/fhir_crud_spec.sql:151',
($SQL$
  SELECT crud.delete('{}'::jsonb, 'Patient', 'nonexisting') -- fhir_crud_spec:151
$SQL$));
```

Source code of expect functions is in src/tests.sql.
