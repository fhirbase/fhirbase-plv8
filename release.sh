#! /bin/bash

set -e

# You should assign DATABASE_URL variable!
# Like this:
# DATABASE_URL=postgres://your_user_name:your_password@localhost:5432/fhirbase_build
# WARNING: `fhirbase_build` database will be destroyed and recreated!

PREV_FBVERSION="1.3.0.22"
FBVERSION="1.3.0.23"

PREV_FBRELEASEDATE="2016-06-08T17:00:00Z"
FBRELEASEDATE="2016-06-09T11:00:00Z"

PREV_FHIRVERSION="1.3.0"
FHIRVERSION="1.3.0"

PGOPTIONS='--client-min-messages=warning'
loadcmd="psql --no-psqlrc --quiet --echo-all --single-transaction \
              --set=ON_ERROR_STOP=1 --pset=pager=off"

# We should temporary connect to `postgres` database
# because `fhirbase_build` database will be droped.
OTHER_DATABASE_URL="${DATABASE_URL/%\/fhirbase_build/\/postgres}"

BUILD_DIR=build/latest

function schema_statement {
    local schema=${1:-public}

    statement="CREATE SCHEMA IF NOT EXISTS $schema;"
    statement="$statement SET search_path TO $schema;"
    echo -n "$statement"
}

npm install

psql "$OTHER_DATABASE_URL" --command='DROP DATABASE IF EXISTS fhirbase_build' || exit 1
psql "$OTHER_DATABASE_URL" --command='CREATE DATABASE fhirbase_build' || exit 1

if [[ ! -f /tmp/fhirbase-release-$PREV_FBVERSION.sql ]]; then
    curl --location \
         https://github.com/fhirbase/fhirbase-plv8/releases/download/v$PREV_FBVERSION/fhirbase-$PREV_FBVERSION.sql.zip \
        | funzip > /tmp/fhirbase-release-$PREV_FBVERSION.sql
fi

FB_SCHEMA=public ./build-commit.sh --rebuild || exit 1
{ echo $(schema_statement "public"); \
  cat /tmp/fhirbase-release-$PREV_FBVERSION.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
{ echo $(schema_statement "public"); cat $BUILD_DIR/patch.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=public npm run test || exit 1

psql "$OTHER_DATABASE_URL" --command='DROP DATABASE IF EXISTS fhirbase_build' || exit 1
psql "$OTHER_DATABASE_URL" --command='CREATE DATABASE fhirbase_build' || exit 1

FB_SCHEMA=foo ./build-commit.sh --rebuild || exit 1
{ echo $(schema_statement "foo") ; cat $BUILD_DIR/build.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=foo npm run test || exit 1

FB_SCHEMA=bar ./build-commit.sh --rebuild || exit 1
{ echo $(schema_statement "bar") ; cat $BUILD_DIR/build.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=bar npm run test || exit 1

fhir_version_sensitive_files="
./src/fhir/fhir_version.coffee
"

for file in $fhir_version_sensitive_files; do
    sed --in-place \
        --expression="s/$PREV_FHIRVERSION/$FHIRVERSION/g" \
        $file || exit 1
done

fhirbase_version_sensitive_files="
./src/core/fhirbase_version.coffee
./vagrant/provision/provision-environment.sh
./perf/perf"

for file in $fhirbase_version_sensitive_files; do
    sed --in-place \
        --expression="s/$PREV_FBVERSION/$FBVERSION/g" \
        $file || exit 1
done

fhirbase_release_date_sensitive_files="
./src/core/fhirbase_version.coffee
"

for file in $fhirbase_release_date_sensitive_files; do
    sed --in-place \
        --expression="s/$PREV_FBRELEASEDATE/$FBRELEASEDATE/g" \
        $file || exit 1
done

psql "$OTHER_DATABASE_URL" --command='DROP DATABASE IF EXISTS fhirbase_build' || exit 1
psql "$OTHER_DATABASE_URL" --command='CREATE DATABASE fhirbase_build' || exit 1

FB_SCHEMA=public ./build-commit.sh --rebuild || exit 1
{ echo $(schema_statement "public") ; cat $BUILD_DIR/build.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=public npm run test || exit 1

cp $BUILD_DIR/build.sql releases/fhirbase-$FBVERSION.sql || exit 1
cp $BUILD_DIR/patch.sql releases/fhirbase-$FBVERSION-patch.sql || exit 1

cd releases || exit 1

zip -r fhirbase-$FBVERSION.sql.zip zip fhirbase-$FBVERSION.sql || exit 1
zip -r fhirbase-$FBVERSION-patch.sql.zip fhirbase-$FBVERSION-patch.sql || exit 1
