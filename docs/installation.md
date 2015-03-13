# Installation Guide

There are several ways to install FHIRbase for end-users and one for developers:

For end-users:

- [Docker](#docker)
- [Vagrant](#vagrant)
- [Ubuntu](#ubuntu)
- [Heroku](#heroku)

For developers:

- [Linux](#development)


### Docker

1.  You can install FHIRbase using docker. First you have to install [docker](https://www.docker.com/) itself according to provided documentation (see the [installation section] (https://docs.docker.com/installation/#installation)).

2.  For this installation we are going to use docker-containers - images, which are stored in the Docker Hub repository or can be built manually. Depending on your goals you can get different docker images:

  * Stable versioned tagged build [fhirbase-build](https://registry.hub.docker.com/u/fhirbase/fhirbase-build). Select the     desired tag from tags, for example 0.0.9-alpha4, and run the following command:

  ```bash
  sudo docker run --name=fhirbase -p 5433:5432 -d fhirbase/fhirbase-build:0.0.9-alpha4
  ```

  * The latest automatically deployed on commit development build [fhirbase](https://registry.hub.docker.com/u/fhirbase/fhirbase). Here there is no need to specify any tags. Just use the command below:

  ```bash
  sudo docker run --name=fhirbase -p 5433:5432 -d fhirbase/fhirbase
  ```
  
  * The third method is to build an image locally from [Dockerfile](https://github.com/fhirbase/fhirbase/blob/master/Dockerfile). First you have to clone FHIRbase project. Then go to the project folder, build an image with name 'fhirbase' and tag 'latest' and run docker.

  ```
  git clone https://github.com/fhirbase/fhirbase/
  cd fhirbase
  sudo docker build -t fhirbase:latest .
  sudo docker run --name=fhirbase -p 5433:5432 -d fhirbase/fhirbase
  ```

3. Check installation

  The process of image loading can take some time. When it is finished FHIRbase will be accessible on localhost with the   following parameters:
  - port: 5433 
  - user: fhirbase 
  - password: fhirbase

  You can check that your container is running, connect to FHIRbase and list database tables by the next commands:
  
  ```
  sudo docker inspect fhirbase
  # read <Config.NetworkSettings.IPAddress> and <Config.Image> of started container
  sudo docker run --rm -i -t <Config.Image> psql -h <Config.NetworkSettings.IPAddress> -U fhirbase -p 5432
  \dt
  ```

  or another way to connect to FHIRbase:

  ```bash
psql -h localhost -p 5433 -U fhirbase
\dt
```
  You will see tables of FHIR resources.

## Vagrant

The simplest and cross-platform installation can be done using vagrant.

1. Install [vagrant](http://www.vagrantup.com/downloads) according to its documentation or check you already have it.

  ```bash
vagrant -v
# Vagrant 1.7.2
```

2. Clone FHIRbase project and go to the project folder.

  ```bash
git clone https://github.com/fhirbase/fhirbase.git
cd fhirbase
```

3. Launch vagrant.

  ```bash
sudo vagrant up
# this action could take a time to load fhirbase container
```

4. Check your ssh-config settings and remember your ip.

  ```bash
vagrant ssh-config
# HostName 172.17.0.15 <<- vm <ip>
#  User vagrant
#  Port 22
```

5. Use your <ip> in the next command to connect to the database.

  ```bash 
psql -h <ip> -p 5432 -U fhirbase
# password: fhirbase
```

(6). If you like GU interfaces use pgadmin with connection
* host: <ip>
* database: fhirbase
* user: fhirbase
* password: fhirbase


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

psql test
#> \dt
```

Here is asci cast for the simplest installation - [https://asciinema.org/a/17236].

### Heroku

1. Register on [Heroku](https://heroku.com).
2. Please ensure that you have Ruby installed.
3. Run this from your terminal:

 ```bash
wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh
```
4. Then login and create app

 ```sh
heroku login
heroku apps:create <your-app-name>
```
5. Create PostgreSQL 9.4 database.

 ```sh
heroku addons:add heroku-postgresql --app your-app-name --version=9.4
```
6. Find YOUR_DB_NAME at https://postgres.heroku.com/databases. Then restore fhirbase dump and generate tables.

 ```sh
curl https://raw.githubusercontent.com/fhirbase/fhirbase-build/master/fhirbase.sql \
  | pg:psql --app your-app-name YOUR_DB_NAME
heroku pg:psql --app your-app-name YOUR_DB_NAME --command 'SELECT fhir.generate_tables()'
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
