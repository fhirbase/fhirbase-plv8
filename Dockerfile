FROM ubuntu:14.10
MAINTAINER Nicola <niquola@gmail.com>, BazZy <bazzy.bazzy@gmail.com>

RUN apt-get update && apt-get -y -q install git python-software-properties software-properties-common

RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8

RUN apt-get -y -q install postgresql-9.4 postgresql-client-9.4 postgresql-contrib-9.4 postgresql-9.4-plv8

ADD . /fhirbase
RUN chown -R postgres /fhirbase

USER postgres

RUN /etc/init.d/postgresql start \
    && psql --command "CREATE USER fhirbase WITH SUPERUSER PASSWORD 'fhirbase';" \
    && createdb -O fhirbase pgdb

RUN /etc/init.d/postgresql start && cd /fhirbase && DB=fhirbase ./runme integrate

USER root

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.4/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.4/main/postgresql.conf``
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.4/main/postgresql.conf
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.4/main/pg_hba.conf

# Expose the PostgreSQL port
EXPOSE 5432

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

# Add VOLUMEs to allow backup of config, logs, socket and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql", "/var/run/postgresql"]


USER postgres
# Set the default command to run when starting the container
CMD ["/usr/lib/postgresql/9.4/bin/postgres", "-D", "/var/lib/postgresql/9.4/main", "-c", "config_file=/etc/postgresql/9.4/main/postgresql.conf"]
