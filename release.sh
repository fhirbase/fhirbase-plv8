#! /bin/bash

set -e

# You should assign DATABASE_URL variable!
# Like this:
# DATABASE_URL=postgres://your_user_name:your_password@localhost:5432/fhirbase_build
# WARNING: `fhirbase_build` database will be destroed and recreated!

export PREV_FBVERSION="fhirbase-0.0.1-beta.4"
export FBVERSION="fhirbase-0.0.1-beta.5"

PGOPTIONS='--client-min-messages=warning'
loadcmd="psql --no-psqlrc --quiet --echo-all --single-transaction \
              --set=ON_ERROR_STOP=1 --pset=pager=off"

# We should temporary connect to `postgres` database
# because `fhirbase_build` database will be droped.
OTHER_DATABASE_URL="${DATABASE_URL/%\/fhirbase_build/\/postgres}"

psql "$OTHER_DATABASE_URL" --command='DROP DATABASE IF EXISTS fhirbase_build' && \
psql "$OTHER_DATABASE_URL" --command='CREATE DATABASE fhirbase_build' && \

FB_SCHEMA=public bash build.sh && \
cat releases/$PREV_FBVERSION.sql | $loadcmd "$DATABASE_URL" > /dev/null && \
time cat tmp/patch.sql | $loadcmd "$DATABASE_URL" > /dev/null && \
FB_SCHEMA=public npm run test && \

psql "$OTHER_DATABASE_URL" --command='DROP DATABASE IF EXISTS fhirbase_build' && \
psql "$OTHER_DATABASE_URL" --command='CREATE DATABASE fhirbase_build' && \

FB_SCHEMA=foo bash build.sh && \
cat tmp/build.sql | $loadcmd "$DATABASE_URL" > /dev/null && \
FB_SCHEMA=foo npm run test && \

FB_SCHEMA=bar bash build.sh && \
cat tmp/build.sql | $loadcmd "$DATABASE_URL" > /dev/null && \
FB_SCHEMA=bar npm run test && \

FB_SCHEMA=public bash build.sh && \
cat tmp/build.sql | $loadcmd "$DATABASE_URL" > /dev/null && \
FB_SCHEMA=public npm run test && \

cp tmp/build.sql  releases/$FBVERSION.sql && \
cp tmp/patch.sql  releases/$FBVERSION-patch.sql && \
cd releases && \

zip -r $FBVERSION.sql.zip zip $FBVERSION.sql && \
zip -r $FBVERSION-patch.sql.zip $FBVERSION-patch.sql
