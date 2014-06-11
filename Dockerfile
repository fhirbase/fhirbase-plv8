FROM ubuntu:14.04
MAINTAINER Mike Lapshin <mikhail.a.lapshin@gmail.com>
RUN apt-get -qq update
RUN apt-get -qqy install git build-essential gettext libreadline6 libreadline6-dev zlib1g-dev flex bison libxml2-dev libxslt-dev
RUN cd /root/ && git clone --depth=1 git://git.postgresql.org/git/postgresql.git postgresql
RUN XML2_CONFIG=`which xml2-config` cd /root/postgresql && ./configure --prefix=/usr/local  --with-libxml && make && make install
RUN cd /root/postgresql/contrib/pgcrypto && make && make install

# RUN git clone https://github.com/akorotkov/jsquery.git /root/postgresql/contrib/jsquery
# RUN cd /root/postgresql/contrib/jsquery && make && make install

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
RUN locale-gen

RUN useradd -m -s /bin/bash fhirbase
RUN echo "fhirbase:fhirbase"|chpasswd

USER fhirbase
RUN echo $LC_ALL
RUN locale
RUN mkdir /home/fhirbase/pgdata &&\
    initdb -D /home/fhirbase/pgdata -E utf8 &&\
    pg_ctl -D /home/fhirbase/pgdata start &&\
    sleep 1 &&\
    psql postgres --command "ALTER USER fhirbase WITH SUPERUSER LOGIN PASSWORD 'fhirbase';" &&\
    psql postgres -c "CREATE DATABASE fhirbase" &&\
    pg_ctl -D /home/fhirbase/pgdata stop


# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  md5" >> /home/fhirbase/pgdata/pg_hba.conf
RUN echo "listen_addresses='*'" >> /home/fhirbase/pgdata/postgresql.conf

# Expose the PostgreSQL port
EXPOSE 5432
CMD ["/usr/local/bin/postgres", "-D", "/home/fhirbase/pgdata/", "-c", "config_file=/home/fhirbase/pgdata/postgresql.conf"]