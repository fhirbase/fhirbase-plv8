FROM ubuntu:14.04
MAINTAINER Nikolay Ryzhikov <niquola@gmail.com>, Mike Lapshin <mikhail.a.lapshin@gmail.com>
RUN apt-get -qq update
RUN apt-get -qqy install git
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
RUN locale-gen

RUN useradd -m -s /bin/bash fhirbase
RUN echo "fhirbase:fhirbase"|chpasswd

RUN adduser fhirbase sudo
# Enable passwordless sudo for users under the "sudo" group
RUN sed -i.bkp -e \
      's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' \

      /etc/sudoers

RUN echo $USER
USER fhirbase
RUN echo $LC_ALL
RUN locale
RUN cd /home/fhirbase && git clone https://github.com/fhirbase/fhirbase.git
RUN sudo su fhirbase -c 'cd /home/fhirbase/fhirbase && source ./local_cfg.sh && ./install-postgres && echo $PG_BIN && ls $PG_BIN'
RUN sudo su root -c 'find /home -type f -name psql'
RUN cd /home/fhirbase/fhirbase && . ./local_cfg.sh && echo $PG_BIN
RUN sudo su fhirbase -c 'export PATH=$PATH:/home/fhirbase/fhirbase/tmp/bin && psql --version'
RUN sudo su fhirbase -c 'export PSQL_ARGS='-h localhost' && export PATH=$PATH:/home/fhirbase/fhirbase/tmp/bin && cd /home/fhirbase/fhirbase && source ./local_cfg.sh && cd /home/fhirbase/fhirbase/dev && ./runme integrate'

# Expose the PostgreSQL port
EXPOSE 5777
# CMD ["/usr/local/bin/postgres", "-D", "/home/fhirbase/pgdata/", "-c", "config_file=/home/fhirbase/pgdata/postgresql.conf"]
