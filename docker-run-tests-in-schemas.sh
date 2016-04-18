#! /bin/bash

export PATH="$HOME"/fhirbase/node_modules/coffee-script/bin:"$PATH" || exit 1
export DATABASE_URL=postgres://fhirbase:fhirbase@localhost:5432/fhirbase || exit 1

sudo service postgresql start || exit 1
cd ~/fhirbase || exit 1
source ~/.nvm/nvm.sh && nvm use 5.3 || exit 1

schemas="foo bar"

for schema in $schemas; do
    FB_SCHEMA=$schema ./build.sh || exit 1
    { echo "CREATE SCHEMA IF NOT EXISTS $schema; SET search_path TO $schema;" \
      && cat tmp/build.sql ; } \
      | psql fhirbase
    [[ ${PIPESTATUS[0]} -ne 0 || ${PIPESTATUS[1]} -ne 0 ]] && exit 1
    FB_SCHEMA=$schema npm run test || exit 1
done
