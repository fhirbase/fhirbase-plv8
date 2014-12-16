FROM ubuntu:14.04
MAINTAINER Nikolay Ryzhikov <niquola@gmail.com>, Mike Lapshin <mikhail.a.lapshin@gmail.com>, Maksym Bodnarchuk <bodnarchuk@gmail.com>
RUN apt-get -qq update
RUN apt-get -qqy install git build-essential gettext libreadline6 libreadline6-dev zlib1g-dev flex bison libxml2-dev libxslt-dev

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

RUN useradd -m -s /bin/bash fhirbase && echo "fhirbase:fhirbase"|chpasswd && adduser fhirbase sudo
RUN echo 'fhirbase ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER fhirbase
ENV HOME /home/fhirbase
ENV PG_BRANCH REL9_4_STABLE
ENV PG_REPO git://git.postgresql.org/git/postgresql.git

RUN git clone -b $PG_BRANCH --depth=1 $PG_REPO $HOME/src
RUN XML2_CONFIG=`which xml2-config` cd $HOME/src && ./configure --prefix=$HOME/bin  --with-libxml && make && make install

ENV SOURCE_DIR $HOME/src
RUN cd $SOURCE_DIR/contrib/pgcrypto && make && make install
RUN cd $SOURCE_DIR/contrib/pg_trgm && make && make install
RUN cd $SOURCE_DIR/contrib/btree_gist && make && make install
RUN cd $SOURCE_DIR/contrib/btree_gin && make && make install

ENV PATH $HOME/bin/bin:$PATH
ENV PGDATA $HOME/data
ENV PGPORT 5432
ENV PGHOST localhost
RUN mkdir -p $PGDATA
RUN initdb -D $PGDATA -E utf8

RUN echo "host all  all    0.0.0.0/0  md5" >> $PGDATA/pg_hba.conf
RUN echo "listen_addresses='*'" >> $PGDATA/postgresql.conf
RUN echo "port=$PGPORT" >> $PGDATA/postgresql.conf

ADD ./dev /home/fhirbase/fhirbase
RUN cd ~/ && pg_ctl -D data -w start && cd ~/fhirbase && ./runme install fhirbase && pg_ctl -w -D ~/data stop
RUN cd ~/ && pg_ctl -D data -w start && psql -c "alter user fhirbase with password 'fhirbase';" && pg_ctl -w -D ~/data stop
EXPOSE 5432
CMD cd ~/ && postgres -D data
