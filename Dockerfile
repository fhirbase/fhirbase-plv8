FROM ubuntu:14.04
MAINTAINER Nikolay Ryzhikov <niquola@gmail.com>, Mike Lapshin <mikhail.a.lapshin@gmail.com>
RUN apt-get -qq update
RUN apt-get -qqy install git
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
RUN locale-gen

RUN useradd -m -s /bin/bash fhirbase
RUN echo "fhirbase:fhirbase"|chpasswd

USER fhirbase
RUN echo $LC_ALL
RUN locale
RUN cd && git clone https://github.com/fhirbase/fhirbase.git
RUN cd fhirbase && source ./local_cfg.sh && ./install-postgres
RUN cd ~/fhirbase/dev && ./runme integrate

# Expose the PostgreSQL port
EXPOSE 5777
# CMD ["/usr/local/bin/postgres", "-D", "/home/fhirbase/pgdata/", "-c", "config_file=/home/fhirbase/pgdata/postgresql.conf"]
