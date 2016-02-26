#! /bin/sh

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose)
      verbose=true
      ;;
    --verbose=*)
      verbose="${1#*=}"
      ;;
    --createdb)
      createdb=true
      ;;
    --createdb=*)
      createdb="${1#*=}"
      ;;
    *)
      printf "***************************\n"
      printf "* Error: Invalid argument.*\n"
      printf "***************************\n"
      exit 1
  esac
  shift
done

directory=$(dirname $0)

export PGHOST=${PGHOST:-localhost}
export PGPORT=${PGPORT:-5432}
export PGDATABASE=${PGDATABASE:-fhirbase}
export PGUSER=${PGUSER:-fhirbase}
export PGPASSWORD=${PGPASSWORD:-your_password}

export PG_SCHEMA=${PG_SCHEMA:-perf}
export OTHER_DATABASE=${OTHER_DATABASE:-postgres}

if [ "$verbose" = true ] ; then
    echo "PGHOST=$PGHOST"
    echo "PGDATABASE=$PGDATABASE"
    echo "PGPORT=$PGPORT"
    echo "PGUSER=$PGUSER"
    echo "PGPASSWORD=$PGPASSWORD"

    echo "PG_SCHEMA=$PG_SCHEMA"
    echo "OTHER_DATABASE=$OTHER_DATABASE"
fi

if [ $createdb = true ] ; then
    read -r -d '' sql << EOF
DROP DATABASE IF EXISTS $PGDATABASE;
EOF
    psql $OTHER_DATABASE --command="$sql" > /dev/null || exit 1

    read -r -d '' sql << EOF
CREATE DATABASE $PGDATABASE WITH OWNER $PGUSER ENCODING = 'UTF8';
EOF
    psql $OTHER_DATABASE --command="$sql" > /dev/null || exit 1

    psql --file="$directory"/../tmp/build.sql > /dev/null || exit 1
fi

echo Load temporary tables into '"'$PG_SCHEMA'"' \
     schema from '"'"$directory"/data'"' directory.
psql --file="$directory"/load.sql > /dev/null || exit 1

read -r -d '' sql << EOF
SET plv8.start_proc = 'plv8_init';
SELECT fhir_create_storage('{"resourceType": "Organization"}'::json);
EOF
psql --command="$sql" > /dev/null || exit 1

echo Create generation functions in '"'$PG_SCHEMA'"' schema.
psql --file="$directory"/generate.sql > /dev/null || exit 1
