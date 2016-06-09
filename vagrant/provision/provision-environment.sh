#!/bin/bash

echo -e "postgres\npostgres" | passwd postgres || exit 1

echo "createuser -s fhir" | sudo -u postgres sh || exit 1
echo "psql -d postgres -c 'create database fhir'" \
    | sudo -u postgres sh || exit 1

echo "curl --location https://github.com/fhirbase/fhirbase-plv8/releases/download/v1.3.0.23/fhirbase-1.3.0.23.sql.zip | funzip | psql -d fhir" \
    | sudo -u postgres sh || exit 1

echo "listen_addresses = '*'" \
     >> /etc/postgresql/9.4/main/postgresql.conf || exit 1
echo "host all all 0.0.0.0/0 trust" \
     >> /etc/postgresql/9.4/main/pg_hba.conf || exit 1

ln -s /vagrant /home/vagrant/fhirbase || exit 1

service postgresql restart || exit 1
