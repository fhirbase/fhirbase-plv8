# Installation guide

For end-users:

- [Docker](#docker)
- [Vagrant](#vagrant)
- [Ubuntu](#ubuntu)
- [Heroku](#heroku)

For developers:

- [Linux](#development)


### Docker

1. Installing docker. Fhirbase could be installed using [docker](https://www.docker.com/)

2. Getting image. You can get docker image 3 ways:

* Stable versioned tagged build [fhirbase-build](https://registry.hub.docker.com/u/fhirbase/fhirbase-build)

Select desired tag from tags for example 0.0.9-alpha4

```bash
sudo docker run --name=fhirbase -p 5433:5432 -d fhirbase/fhirbase-build:0.0.9-alpha4
```

* Auto last development build on commit [fhirbase](https://registry.hub.docker.com/u/fhirbase/fhirbase)

```bash
sudo docker run --name=fhirbase -p 5433:5432 -d fhirbase/fhirbase
```
* Build image locally from [Dockerfile](https://github.com/fhirbase/fhirbase/blob/master/Dockerfile)

You could build image by yourself:

```
git clone https://github.com/fhirbase/fhirbase/
cd fhirbase
sudo docker build -t fhirbase:latest .
sudo docker run --name=fhirbase -p 5433:5432 -d fhirbase/fhirbase
```

3. Check installation

You have to wait until image is loaded after that fhirbase will be accessible on localhost port: 5433 user: fhirbase password: fhirbase

To check if container is running

```
sudo docker inspect fhirbase
# read <Config.NetworkSettings.IPAddress> and <Config.Image> of started container
sudo docker run --rm -i -t <Config.Image> psql -h <Config.NetworkSettings.IPAddress> -U fhirbase -p 5432
\dt
```

or

```bash
psql -h localhost -p 5433 -U fhirbase
\dt
```
you will see resource tables

## Vagrant

The simplest and cross-platform installation could be done using vagrant.

1. Install [vagrant](http://www.vagrantup.com/downloads)

```bash
vagrant -v
# Vagrant 1.7.2
git clone https://github.com/fhirbase/fhirbase.git
cd fhirbase
sudo vagrant up
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
