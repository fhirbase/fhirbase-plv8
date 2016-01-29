#! /bin/bash

set -e

# You should assign DATABASE_URL variable!
# Like this:
# DATABASE_URL=postgres://your_user_name:your_password@localhost:5432/fhirbase_build
# WARNING: `fhirbase_build` database will be destroed and recreated!

PREV_FBVERSION="0.0.1-beta.14"
FBVERSION="0.0.1-beta.15"

PGOPTIONS='--client-min-messages=warning'
loadcmd="psql --no-psqlrc --quiet --echo-all --single-transaction \
              --set=ON_ERROR_STOP=1 --pset=pager=off"

# We should temporary connect to `postgres` database
# because `fhirbase_build` database will be droped.
OTHER_DATABASE_URL="${DATABASE_URL/%\/fhirbase_build/\/postgres}"

function schema_statement {
    local schema=${1:-public}

    statement="CREATE SCHEMA IF NOT EXISTS $schema;"
    statement="$statement SET search_path TO $schema;"
    echo -n "$statement"
}

sed --in-place \
    --expression="s/$PREV_FBVERSION/$FBVERSION/" \
    ./src/core/version.coffee || exit 1

psql "$OTHER_DATABASE_URL" --command='DROP DATABASE IF EXISTS fhirbase_build' || exit 1
psql "$OTHER_DATABASE_URL" --command='CREATE DATABASE fhirbase_build' || exit 1

FB_SCHEMA=public bash build.sh || exit 1
curl --location \
     --output ./releases/fhirbase-$PREV_FBVERSION.sql.zip \
     https://github.com/fhirbase/fhirbase-plv8/releases/download/v$PREV_FBVERSION/fhirbase-$PREV_FBVERSION.sql.zip || exit 1
unzip ./releases/fhirbase-$PREV_FBVERSION.sql.zip -d ./releases/ || exit 1
{ echo $(schema_statement "public"); cat releases/fhirbase-$PREV_FBVERSION.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
{ echo $(schema_statement "public"); cat tmp/patch.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=public npm run test || exit 1

psql "$OTHER_DATABASE_URL" --command='DROP DATABASE IF EXISTS fhirbase_build' || exit 1
psql "$OTHER_DATABASE_URL" --command='CREATE DATABASE fhirbase_build' || exit 1

FB_SCHEMA=foo bash build.sh || exit 1
{ echo $(schema_statement "foo") ; cat tmp/build.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=foo npm run test || exit 1

FB_SCHEMA=bar bash build.sh || exit 1
{ echo $(schema_statement "bar") ; cat tmp/build.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=bar npm run test || exit 1

FB_SCHEMA=public bash build.sh || exit 1
{ echo $(schema_statement "public") ; cat tmp/build.sql; } \
    | $loadcmd "$DATABASE_URL" > /dev/null || exit 1
FB_SCHEMA=public npm run test || exit 1

cp tmp/build.sql releases/fhirbase-$FBVERSION.sql || exit 1
cp tmp/patch.sql releases/fhirbase-$FBVERSION-patch.sql || exit 1

cd releases || exit 1

zip -r fhirbase-$FBVERSION.sql.zip zip fhirbase-$FBVERSION.sql || exit 1
zip -r fhirbase-$FBVERSION-patch.sql.zip fhirbase-$FBVERSION-patch.sql || exit 1
