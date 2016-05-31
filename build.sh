#! /bin/bash

set -e

COMMIT=`git rev-parse HEAD`
BUILD_DIR=build/$COMMIT
rebuild=${rebuild:--1}

while [ $# -gt 0 ]; do
    case "$1" in
        --rebuild)
            let rebuild=1
            ;;
        *)
            printf "***************************\n"
            printf "* Error: Invalid argument.*\n"
            printf "***************************\n"
            exit 1
    esac
    shift
done

[[ $rebuild -eq 1 ]] && rm -rf -d $BUILD_DIR

git submodule init
git submodule update

if [[ ! -d $BUILD_DIR ]]; then

  echo "Build new version of fhirbase $COMMIT"

  cd plpl
  npm install
  cd ..
  npm install

  mkdir -p $BUILD_DIR

  coffee utils/generate_migrations.coffee -n > $BUILD_DIR/schema.sql
  coffee utils/generate_patch.coffee -n > $BUILD_DIR/patch.sql

  plpl/bin/plpl compile $BUILD_DIR/code.sql

  cat $BUILD_DIR/schema.sql > $BUILD_DIR/build.sql
  cat $BUILD_DIR/patch.sql >> $BUILD_DIR/build.sql
  cat $BUILD_DIR/code.sql >> $BUILD_DIR/build.sql
  echo $COMMIT > $BUILD_DIR/version

  cat $BUILD_DIR/code.sql >> $BUILD_DIR/patch.sql

  rm -f `pwd`/build/latest
  ln -s `pwd`/$BUILD_DIR `pwd`/build/latest
else
  echo "Build already exists for revision $COMMIT"
  echo "If you whant rebuild run `build.sh --rebuild`"
  exit 1
fi
# psql postgres -c 'drop database build' && psql postgres -c "create database build with ENCODING = 'UTF-8' LC_CTYPE = 'ru_RU.UTF-8' LC_COLLATE = 'ru_RU.UTF-8'   template = template0" && cat $BUILD_DIR/build.sql | psql build && npm run test
