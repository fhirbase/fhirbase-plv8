# Installation guide

- [Docker](#docker)
- [Vagrant](#vagrant)
- [Ubuntu](#ubuntu)
- [Heroku](#heroku)
- [Development](#development)

## Vagrant

The simplest and cross-platform installation could be done using vagrant.

Install [vagrant](http://www.vagrantup.com/downloads)

```bash
vagrant -v
# Vagrant 1.7.2
git clone https://github.com/fhirbase/fhirbase.git
cd fhirbase
vagrant up
# this action could take a time to load fhirbase container

vagrant ssh-config
# HostName 172.17.0.15 <<- vm <ip>
#  User vagrant
#  Port 22


psql -h <ip> -p 5432 -U fhirbase
# password: fhirbase

# if you like gui interfaces,
# use pgadmin with connection
# * host: <ip>
# * database: fhirbase
# * user: fhirbase
# * password: fhirbase
```
## Ubuntu

Requirements:
* PostgreSQL 9.4
* pgcrypto
* pg_trgm
* btree_gin
* btree_gist

You can install fhirbase:

```bash
sudo apt-get install postgresql-9.4 postgresql-contrib-9.4 curl
# create local user for ident auth
sudo su postgres -c 'createuser -s <you-local-user>'
# create empty database
psql -d postgres -c 'create database test'
# install last version of fhirbase
curl https://raw.githubusercontent.com/fhirbase/fhirbase-build/master/fhirbase.sql | psql -d test
# generate tables
psql -d test -c 'SELECT fhir.generate_tables()'

psql
#> \dt
```

Here is asci cast for simplest installation - [https://asciinema.org/a/17236].

### Install with docker

Fhirbase could be installed using [docker](https://www.docker.com/)

```bash
#run database container
docker run --name=fhirbase -d fhirbase/fhirbase-build

docker inspect fhirbase
# read ip of started container

docker run --rm -i -t fhirbase/fhirbase-build psql -h <container-ip> -U fhirbase -p 5432
```

There are two images on dockerhub:
 * [fhirbase](https://registry.hub.docker.com/u/fhirbase/fhirbase) - auto-build
 * [fhirbase-build](https://registry.hub.docker.com/u/fhirbase/fhirbase-build) - manual build (more robust)

You could build image by yourself:

```
git clone https://github.com/fhirbase/fhirbase/
cd fhirbase
docker build -t fhirbase:latest .
#run database container
docker run --name=fhirbase -d fhirbase

docker inspect fhirbase
# read ip of started container

docker run --rm -i -t fhirbase psql -h <container-ip> -U fhirbase -p 5432
```

### Development

For development environment:

```bash
sudo apt-get install -qqy postgresql-9.4 postgresql-contrib-9.4 curl python
sudo su postgres -c 'createuser -s <you-local-user>'
export PGUSER=<you-local-user>
export DB=test

git clone https://github.com/fhirbase/fhirbase
cd fhirbase
./runme integrate
```

### Heroku

Register on [Heroku][]

[Heroku]: https://heroku.com

Then login and create app

```sh
heroku login
heroku apps:create your-app-name
```

Then create PostgreSQL 9.4 database

```sh
heroku addons:add heroku-postgresql --app your-app-name --version=9.4
```

Then restore fhirbase dump and generate tables

```sh
curl https://raw.githubusercontent.com/fhirbase/fhirbase-build/master/fhirbase.sql \
  | pg:psql --app your-app-name YOUR_DB_NAME
pg:psql --app your-app-name YOUR_DB_NAME --command 'SELECT fhir.generate_tables()'
```
