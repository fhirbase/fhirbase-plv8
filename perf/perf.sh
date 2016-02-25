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

if [ $verbose = true ] ; then
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
    psql $OTHER_DATABASE --command="$sql" || exit 1

    read -r -d '' sql << EOF
CREATE DATABASE $PGDATABASE WITH OWNER $PGUSER ENCODING = 'UTF8';
EOF
    psql $OTHER_DATABASE --command="$sql" || exit 1

    psql --file="$directory"/../tmp/build.sql || exit 1
fi

read -r -d '' alert << EOF
Load temporary tables into "$PG_SCHEMA" schema from "${directory}/data" directory.
EOF
echo $alert || exit 1
psql --file="$directory"/load.sql || exit 1

read -r -d '' alert << EOF
Create generation functions in "$PG_SCHEMA" schema.
EOF
echo $alert || exit 1
psql --file="$directory"/generate.sql || exit 1
