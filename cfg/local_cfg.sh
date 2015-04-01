export BUILD_DIR=`pwd`/../.build

export PGDATA=$BUILD_DIR/data
export PGPORT=5777
export PGHOST=localhost
export PGUSER=`whoami`

export SOURCE_DIR=$BUILD_DIR/src

export PG_BIN=$BUILD_DIR/bin
export PG_CONFIG=$BUILD_DIR

export PATH=$PG_BIN:$PATH
