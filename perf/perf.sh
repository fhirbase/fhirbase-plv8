#! /bin/sh

directory=$(dirname $0)

export PGHOST=${PGHOST:-localhost}
export PGPORT=${PGPORT:-5432}
export PGDATABASE=${PGDATABASE:-fhirbase}
export PGUSER=${PGUSER:-fhirbase}
export PGPASSWORD=${PGPASSWORD:-your_password}

export PG_SCHEMA=${PG_SCHEMA:-perf}
export OTHER_DATABASE=${OTHER_DATABASE:-postgres}

# echo $PGHOST
# echo $PGDATABASE
# echo $PGPORT
# echo $PGUSER
# echo $PGPASSWORD

# echo $PG_SCHEMA
# echo $OTHER_DATABASE

read -r -d '' SQL << EOF
DROP DATABASE IF EXISTS $PGDATABASE;
EOF
psql $OTHER_DATABASE --command="$SQL" || exit 1

read -r -d '' SQL << EOF
CREATE DATABASE $PGDATABASE WITH OWNER $PGUSER ENCODING = 'UTF8';
EOF
psql $OTHER_DATABASE --command="$SQL" || exit 1

psql --file="$directory"/../tmp/build.sql || exit 1

read -r -d '' SQL << EOF
SET plv8.start_proc = 'plv8_init';
SELECT fhir_create_storage('{"resourceType": "Organization"}'::json);
EOF
psql --command="$SQL" || exit 1

echo 'Load temporary tables into "'$PG_SCHEMA \
     '" schema from "'"$directory"'/data" directory.' || exit 1
psql --file="$directory"/load.sql || exit 1

echo 'Create generation functions in "'$PG_SCHEMA'" schema.' || exit 1
psql --file="$directory"/generate.sql || exit 1
