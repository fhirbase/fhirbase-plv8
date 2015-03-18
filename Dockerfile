FROM postgres:9.4.1

MAINTAINER Nikolay Ryzhikov <niquola@gmail.com>, Mike Lapshin <mikhail.a.lapshin@gmail.com>, Maksym Bodnarchuk <bodnarchuk@gmail.com>
RUN apt-get -qq update
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
RUN apt-get -qqy install python sudo

ENV PGDATA /data
RUN mkdir -p $PGDATA && chown postgres -R $PGDATA
RUN gosu postgres initdb -D $PGDATA -E utf8

RUN echo 'postgres ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

ENV PGDATABASE fhirbase
ADD . /fhirbase

RUN chown -R postgres /fhirbase

USER postgres
RUN pg_ctl -w start && cd /fhirbase && psql -d postgres -c "create database $PGDATABASE" && env DB=$PGDATABASE ./runme integrate && pg_ctl -w stop
RUN pg_ctl -w start && createuser -s fhirbase && psql -c "alter user fhirbase with password 'fhirbase'; select fhir.generate_tables(); select fhir.index_all_resources()" && pg_ctl -w stop

RUN echo "host all  all    0.0.0.0/0  md5" >> $PGDATA/pg_hba.conf
RUN echo "listen_addresses='*'" >> $PGDATA/postgresql.conf

EXPOSE 5432
CMD postgres
