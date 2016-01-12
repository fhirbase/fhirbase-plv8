#!/bin/bash
echo -e "postgres\npostgres" | passwd postgres

echo "createuser -s fhir" | sudo -u postgres sh
echo "psql -d postgres -c 'create database fhir'" | sudo -u postgres sh

echo "curl https://raw.githubusercontent.com/fhirbase/fhirbase-build/master/fhirbase.sql | psql -d fhir" | sudo -u postgres sh

echo "psql -d fhir -c 'SELECT fhir.generate_tables()'" | sudo -u postgres sh

echo "listen_addresses = '*'" >> /etc/postgresql/9.4/main/postgresql.conf
echo "host all all 0.0.0.0/0 trust" >> /etc/postgresql/9.4/main/pg_hba.conf

ln -s /vagrant /home/vagrant/fhirbase

service postgresql restart
