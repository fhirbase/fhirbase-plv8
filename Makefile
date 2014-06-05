# contrib/fhirbase/Makefile

MODULE_big = fhirbase

EXTENSION = fhirbase
DATA = fhirbase--1.0.sql

REGRESS = fhirbase

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/fhirbase
top_builddir = ../fhirbase-2/pg/postgresql
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
