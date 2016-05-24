#! /bin/bash

schemas="${schemas:-public}"

while [ $# -gt 0 ]; do
    case "$1" in
        --install-fhirbase)
            install_fhirbase=1
            ;;
        --schemas=*)
            export schemas="${1#*=}"
            ;;
        *)
            printf "***************************\n"
            printf "* Error: Invalid argument.*\n"
            printf "***************************\n"
            exit 1
    esac
    shift
done

export PATH="$HOME"/fhirbase/node_modules/coffee-script/bin:"$PATH" || exit 1
export DATABASE_URL=postgres://fhirbase:fhirbase@localhost:5432/fhirbase || exit 1

sudo service postgresql start || exit 1
cd ~/fhirbase || exit 1
source ~/.nvm/nvm.sh && nvm use 6.2.0 || exit 1

for schema in $schemas; do
    if [ "$install_fhirbase" = 1 ] ; then
        FB_SCHEMA=$schema ./build.sh || exit 1
        { echo "CREATE SCHEMA IF NOT EXISTS $schema; SET search_path TO $schema;" \
          && cat build/latest/build.sql ; } \
          | psql fhirbase
        [[ ${PIPESTATUS[0]} -ne 0 || ${PIPESTATUS[1]} -ne 0 ]] && exit 1
    fi

    FB_SCHEMA=$schema npm run test || exit 1
done
