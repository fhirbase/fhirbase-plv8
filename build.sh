#! /bin/bash

set -e

git submodule init
git submodule update

cd plpl
npm install
cd ..
npm install

COMMIT=`git rev-parse HEAD`
BUILD_DIR=build/$COMMIT

if [[ ! -d $BUILD_DIR ]]; then

  echo "Build new version of fhirbase $COMMIT"

  mkdir -p $BUILD_DIR

  coffee utils/generate_migrations.coffee -n > $BUILD_DIR/schema.sql
  coffee utils/generate_patch.coffee -n > $BUILD_DIR/patch.sql

  plpl/bin/plpl compile $BUILD_DIR/code.sql

  cat $BUILD_DIR/schema.sql > $BUILD_DIR/build.sql
  cat $BUILD_DIR/patch.sql >> $BUILD_DIR/build.sql
  cat $BUILD_DIR/code.sql >> $BUILD_DIR/build.sql
  echo $COMMIT > $BUILD_DIR/version

  cat $BUILD_DIR/code.sql >> $BUILD_DIR/patch.sql

  ln -s `pwd`/$BUILD_DIR `pwd`/build/latest
else
  echo "Build $COMMIT already exists"
fi
# psql postgres -c 'drop database build' && psql postgres -c "create database build with ENCODING = 'UTF-8' LC_CTYPE = 'ru_RU.UTF-8' LC_COLLATE = 'ru_RU.UTF-8'   template = template0" && cat $BUILD_DIR/build.sql | psql build && npm run test
