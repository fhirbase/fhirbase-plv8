export BUILD_DIR=/home/travis/build/fhirbase/fhirbase/db

export PGDATA=$BUILD_DIR/data
export PGPORT=5777
export PGHOST=localhost

export SOURCE_DIR=$BUILD_DIR/src

export PG_BIN=$BUILD_DIR/bin
export PG_CONFIG=$BUILD_DIR

export PATH=$PATH:$PG_BIN
