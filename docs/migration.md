## Migration


* migrate to empty database, as fast as possible (ala restore)
* migrate existing database
* migrate by sql scripts (1 sql file per release)


Problems:

* How to use API in migrations create_storage, create_resource & load resource ???
* Is this right ???
* Indexes updates ???


Distrib:

version-01.sql
version-02.sql
version-03.sql
version-04.sql

patch-01-02.sql
patch-02-03.sql
patch-03-04.sql


Initial decision:

* build it by hands :)
* use github releases
